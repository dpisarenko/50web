require_relative '../lib/form_filter.rb'
require 'b50d-config.rb'
require 'b50d/peeps'
require 'b50d/sivers-comments'
require 'sinatra/base'
require '../lib/db2js.rb'

PP = B50D::Peeps.new(API_KEY, API_PASS)
SC = B50D::SiversComments.new(API_KEY, API_PASS)

DBP = getdb('peeps')
DBS = getdb('sivers')

## DYNAMIC (non-static) parts of sivers.org:
# 1. posting a comment
# 2. mailing list: un/subscribe
# 3. ebook: post name&email / lopass URL to download
# 4. AnythingYouWant: post proof, login, MP3-list, download
# 5. password forgot/reset

## URL paths for nginx to pass to proxy:
#  ^/(comments|list/|list\Z|u/|ayw/|download/)

class SiversOrg < Sinatra::Base

	log = File.new('/tmp/SiversOrg.log', 'a+')
	log.sync = true

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/sivers.org') }
	end

	before do
		env['rack.errors'] = log
	end

	# nginx might rewrite looking for /uri/home or just /uri/. both are wrong.
	get %r{/home\Z|/\Z} do
		redirect '/'
	end

	# COMMENTS: post to add comment 
	post '/comments' do
		comment = FormFilter::comment(request.env, SC)
		if comment && comment[:id]
			redirect '%s#comment-%d' % [request.referrer, comment[:id]]
		else
			redirect request.referrer
		end
	end

	# LIST: pre-authorized URL to show form for changing settings / unsubscribing
	get %r{\A/list/([0-9]+)/([a-zA-Z0-9]{4})\Z} do |person_id, lopass|
		@bodyid = 'list'
		@pagetitle = 'email list'
		ok, p = DBP.call('get_person_lopass', person_id, lopass)
		@show_name = ok ? p[:name] : ''
		@show_email = ok ? p[:email] : ''
		erb :list
	end

	# LIST: just show the static form
	get '/list' do
		@bodyid = 'list'
		@pagetitle = 'email list'
		@show_name = @show_email = ''
		erb :list
	end

	# LIST: handle posting of list signup or changing settings
	post '/list' do
		if FormFilter::mailinglist(request.env, PP)
			redirect('/thanks?for=list')
		else
			redirect '/list'
		end
	end

	# DOWNLOAD: id+lopass auth to get a file
	get %r{\A/download/([0-9]+)/([a-zA-Z0-9]{4})/([a-zA-Z0-9\._-]+)\Z} do |person_id, lopass, filename|
		whitelist = %w(DerekSivers.pdf)
		redirect '/sorry?for=notfound' unless whitelist.include?(filename)
		redirect '/sorry?for=login' unless DBP.call('get_person_lopass', person_id, lopass)[0]
		send_file "/var/www/htdocs/downloads/#{filename}"
	end

	# sivers.org/pdf posts here to request ebook. creates stat + emails them link.
	post '/download/ebook' do
		ok, p = DBP.call('create_person', params[:name], params[:email])
		redirect '/pdf' unless ok
		DBP.call('add_stat', p[:id], 'ebook', 'requested')
		ok, b = DBP.call('parsed_formletter', 5, p[:id])
		DBP.call('new_email', p[:id], b[:body],
			"#{p[:address]} - How to Call Attention to Your Music", 'derek@sivers')
		redirect '/thanks?for=pdf'
	end

	# PASSWORD: semi-authorized. show form to make/change real password
	get %r{\A/u/([0-9]+)/([a-zA-Z0-9]{8})\Z} do |person_id, newpass|
		redirect '/sorry?for=badurlid' unless DBP.call('get_person_newpass', person_id, newpass)[0]
		@person_id = person_id
		@newpass = newpass
		@bodyid = 'newpass'
		@pagetitle = 'new password'
		erb :newpass
	end

	# PASSWORD: posted here to make/change it. then log in with cookie
	post '/u/password' do
		ok, p = DBP.call('get_person_newpass', params[:person_id], params[:newpass])
		redirect '/sorry?for=badurlid' unless ok
		redirect '/sorry?for=shortpass' unless params[:password].to_s.size >= 4
		ok, p = DBP.call('set_password', p[:id], params[:password])
		ok, res = DBP.call('cookie_from_id', p[:id], request.env['SERVER_NAME'])
		response.set_cookie('ok', value: res[:cookie], path: '/', httponly: true)
		redirect '/ayw/list'
	end

	# PASSWORD: forgot? form to enter email
	get '/u/forgot' do
		@bodyid = 'forgot'
		@pagetitle = 'forgot password'
		erb :forgot
	end

	# PASSWORD: email posted here. send password reset link
	post '/u/forgot' do
		ok, p = DBP.call('get_person_email', params[:email])
		redirect '/sorry?for=noemail' unless ok
		DBP.call('make_newpass', p[:id])
		ok, b = DBP.call('parsed_formletter', 1, p[:id])
		DBP.call('new_email', p[:id], b[:body],
			"#{p[:address]} - your password reset link", 'derek@sivers')
		redirect '/thanks?for=reset'
	end

	# AYW post code word + name & email. if right, emails login link
	# (if you are reading this, yes the codeword is here. it's intentionally not very secret.)
	post '/ayw/proof' do
		redirect '/sorry?for=aywcode' unless /utopia/i === params[:code]
		ok, p = DBP.call('create_person', params[:name], params[:email])
		redirect '/a' unless ok
		DBP.call('add_stat', p[:id], 'ayw', 'a')
		ok, b = DBP.call('parsed_formletter', 4, p[:id])
		DBP.call('new_email', p[:id], b[:body],
			"#{p[:address]} - your MP3 download link", 'derek@sivers')
		redirect '/thanks?for=ayw'
	end

	# log in form to get to AYW MP3 download area
	get '/ayw/login' do
		redirect '/ayw/list' if DBP.call('get_person_cookie', request.cookies['ok'])[0]
		@bodyid = 'ayw'
		@pagetitle = 'log in for MP3 downloads'
		erb :ayw_login
	end

	# post login form to get into list of MP3s
	post '/ayw/login' do
		ok, res = DBP.call('cookie_from_login', params[:email], params[:password], request.env['SERVER_NAME'])
		if ok
			response.set_cookie('ok', value: res[:cookie], path: '/', httponly: true)
			redirect '/ayw/list'
		else
			redirect '/sorry?for=badlogin'
		end
	end

	# AYW list of MP3 downloads - only for the authorized
	get '/ayw/list' do
		redirect '/ayw/login' unless DBP.call('get_person_cookie', request.cookies['ok'])[0]
		@bodyid = 'ayw'
		@pagetitle = 'MP3 downloads for Anything You Want book'
		erb :ayw_list
	end

	# AYW MP3 downloads 
	get %r{\A/ayw/download/([A-Za-z-]+.zip)\Z} do |zipfile|
		redirect '/sorry?for=login' unless DBP.call('get_person_cookie', request.cookies['ok'])[0]
		redirect '/ayw/list' unless %w(AnythingYouWant.zip CLASSICAL-AnythingYouWant.zip COUNTRY-AnythingYouWant.zip FOLK-AnythingYouWant.zip JAZZ-AnythingYouWant.zip OTHER-AnythingYouWant.zip POP-AnythingYouWant.zip ROCK-AnythingYouWant.zip SAMPLER-AnythingYouWant.zip SINGSONG-AnythingYouWant.zip URBAN-AnythingYouWant.zip WORLD-AnythingYouWant.zip).include? zipfile
		redirect "/file/#{zipfile}"
	end

end
