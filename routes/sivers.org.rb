require 'sinatra/base'
require 'b50d/getdb'
require 'b50d-config.rb'
require 'net/http'
require 'resolv'

## DYNAMIC (non-static) parts of sivers.org:
# 1. posting a comment
# 2. mailing list: un/subscribe
# 3. ebook: post name&email / lopass URL to download
# 4. AnythingYouWant: post proof, login, MP3-list, download
# 5. password forgot/reset

## URL paths for nginx to pass to proxy:
#  ^/(comments|list/|list\Z|u/|ayw/|download/)

# README: http://akismet.com/development/api/#comment-check
def akismet_ok?(api_key, params)
	params.each {|k,v| params[k] = URI.encode_www_form_component(v)}
	uri = URI("http://#{api_key}.rest.akismet.com/1.1/comment-check")
	'true' != Net::HTTP.post_form(uri, params).body
end

# README: http://www.projecthoneypot.org/httpbl_api.php
def honeypot_ok?(api_key, ip)
	addr = '%s.%s.dnsbl.httpbl.org' %
		[api_key, ip.split('.').reverse.join('.')]
	begin
		Timeout::timeout(1) do
			response = Resolv::DNS.new.getaddress(addr).to_s
			if /127\.[0-9]+\.([0-9]+)\.[0-9]+/.match response
				return false if $1.to_i > 5
			end
		end
		true
	rescue
		true
	end
end

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
		@db = getdb('peeps')
	end

	helpers do
		def sorry(msg)
			redirect to('/sorry?for=' + msg)
		end
	end

	# nginx might rewrite looking for /uri/home or just /uri/. both are wrong.
	get %r{/home\Z|/\Z} do
		redirect '/'
	end

	# COMMENTS: post to add comment 
	post '/comments' do
		goodref = %r{\Ahttps?://sivers\.(dev|org)/([a-z0-9_-]{1,32})\Z}
		sorry 'badref' unless m = goodref.match(env['HTTP_REFERER'])
		uri = m[2]
		sorry 'noname' unless params[:name] && params[:name].size > 0
		sorry 'noemail' unless params[:email] && /\A\S+@\S+\.\S+\Z/ === params[:email]
		sorry 'nocomment' unless params[:comment] && params[:comment].size > 2
		akismet_params = {
			blog: 'http://sivers.org/',
			user_ip: env['REMOTE_ADDR'],
			user_agent: env['HTTP_USER_AGENT'],
			referrer: env['HTTP_REFERER'],
			permalink: env['HTTP_REFERER'],
			comment_type: 'comment',
			comment_author: env['rack.request.form_hash']['name'],
			comment_author_email: env['rack.request.form_hash']['email'],
			comment_content: env['rack.request.form_hash']['comment'],
			blog_lang: 'en',
			blog_charset: 'UTF-8'}
		sorry 'akismet' unless akismet_ok?(AKISMET, akismet_params)
		sorry 'honeypot' unless honeypot_ok?(HONEYPOT, env['REMOTE_ADDR'])
		sivers = getdb('sivers')
		tags = %r{</?[^>]+?>}    # strip HTML tags
		ok, res = sivers.call('add_comment', uri,
			params[:name].strip.gsub(tags, ''),
			params[:email],
			params[:comment].strip.gsub(tags, ''))
		if ok
			redirect '%s#comment-%d' % [request.referrer, res[:id]]
		else
			sorry 'unsaved'
		end
	end

	# LIST: pre-authorized URL to show form for changing settings / unsubscribing
	get %r{\A/list/([0-9]+)/([a-zA-Z0-9]{4})\Z} do |person_id, lopass|
		@bodyid = 'list'
		@pagetitle = 'email list'
		ok, p = @db.call('get_person_lopass', person_id, lopass)
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
		goodref = %r{\Ahttps?://sivers\.(dev|org)/}
		sorry 'badref' unless goodref.match env['HTTP_REFERER']
		sorry 'noname' unless params[:name] && params[:name].size > 0
		sorry 'noemail' unless params[:email] && /\A\S+@\S+\.\S+\Z/ === params[:email]
		sorry 'nocomment' unless %w(some all none).include? params[:listype]
		sorry 'honeypot' unless honeypot_ok?(HONEYPOT, env['REMOTE_ADDR'])
		ok, res = @db.call('list_update', params[:name], params[:email], params[:listype])
		if ok
			redirect('/thanks?for=list')
		else
			sorry 'unsaved'
		end
	end

	# DOWNLOAD: id+lopass auth to get a file
	get %r{\A/download/([0-9]+)/([a-zA-Z0-9]{4})/([a-zA-Z0-9\._-]+)\Z} do |person_id, lopass, filename|
		whitelist = %w(DerekSivers.pdf)
		redirect '/sorry?for=notfound' unless whitelist.include?(filename)
		redirect '/sorry?for=login' unless @db.call('get_person_lopass', person_id, lopass)[0]
		send_file "/var/www/htdocs/downloads/#{filename}"
	end

	# sivers.org/pdf posts here to request ebook. creates stat + emails them link.
	post '/download/ebook' do
		ok, p = @db.call('create_person', params[:name], params[:email])
		redirect '/pdf' unless ok
		@db.call('add_stat', p[:id], 'ebook', 'requested')
		@db.call('send_person_formletter', p[:id], 5, 'derek@sivers')
		redirect '/thanks?for=pdf'
	end

	# PASSWORD: semi-authorized. show form to make/change real password
	get %r{\A/u/([0-9]+)/([a-zA-Z0-9]{8})\Z} do |person_id, newpass|
		ok, _ = @db.call('get_person_newpass', person_id, newpass)
		redirect '/sorry?for=badurlid' unless ok
		@person_id = person_id
		@newpass = newpass
		@bodyid = 'newpass'
		@pagetitle = 'new password'
		erb :newpass
	end

	# PASSWORD: posted here to make/change it. then log in with cookie
	post '/u/password' do
		ok, p = @db.call('get_person_newpass', params[:person_id], params[:newpass])
		redirect '/sorry?for=badurlid' unless ok
		redirect '/sorry?for=shortpass' unless params[:password].to_s.size >= 4
		ok, p = @db.call('set_password', p[:id], params[:password])
		ok, res = @db.call('cookie_from_id', p[:id], request.env['SERVER_NAME'])
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
		ok, p = @db.call('get_person_email', params[:email])
		redirect '/sorry?for=emailnf' unless ok
		@db.call('make_newpass', p[:id])
		ok, b = @db.call('parsed_formletter', 1, p[:id])
		@db.call('new_email', p[:id], b[:body],
			"#{p[:address]} - your password reset link", 'derek@sivers')
		redirect '/thanks?for=reset'
	end

end
