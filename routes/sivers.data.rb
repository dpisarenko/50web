require 'sinatra/base'
require 'b50d/getdb'

class SiversData < Sinatra::Base

	log = File.new('/tmp/SiversData.log', 'a+')
	log.sync = true

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/sivers.data') }
	end

	before do
		env['rack.errors'] = log
		@db = getdb('peeps')
	end

	helpers do
		def h(text)
			Rack::Utils.escape_html(text)
		end

		def sorry(msg)
			redirect to('/sorry?for=' + msg)
		end
	end

	get '/' do
		@pagetitle = 'your data'
		erb :home
	end

	get %r{\A/newpass/([0-9]+)/([0-9a-zA-Z]{8})\Z} do |id, newpass|
		ok, @person = @db.call('get_person_newpass', id, newpass)
		if ok
			@pagetitle = 'make a password'
			erb :newpass_good
		else
			@pagetitle = 'expired link'
			erb :newpass_bad
		end
	end

	post '/newpass' do
		redirect to('/login?err=missing') unless (params[:id] && params[:newpass])
		id = params[:id]
		newpass = params[:newpass]
		ok, _ = @db.call('get_person_newpass', id, newpass)
		redirect to('/login?err=badid') unless ok
		unless params[:setpass].length > 3
			redirect to('/newpass/%d/%s' % [id, newpass])
		end
		ok, _ = @db.call('set_password', id, params[:setpass])
		redirect to('/login?err=bad_set_pass') unless ok
		ok, res = @db.call('add_api', id, 'Sivers')
		redirect to('/login?err=wrong') unless ok
		response.set_cookie('person_id', value: id, path: '/', secure: true, httponly: true)
		response.set_cookie('api_key', value: res[:akey], path: '/', secure: true, httponly: true)
		response.set_cookie('api_pass', value: res[:apass], path: '/', secure: true, httponly: true)
		redirect to('/')
	end

	# PASSWORD: semi-authorized. show form to make/change real password
	get %r{\A/u/([0-9]+)/([a-zA-Z0-9]{8})\Z} do |person_id, newpass|
		ok, _ = @db.call('get_person_newpass', person_id, newpass)
		sorry 'badurlid' unless ok
		@person_id = person_id
		@newpass = newpass
		@bodyid = 'newpass'
		@pagetitle = 'new password'
		erb :newpass
	end

	# PASSWORD: posted here to make/change it. then log in with cookie
	post '/password' do
		ok, p = @db.call('get_person_newpass', params[:person_id], params[:newpass])
		sorry 'badurlid' unless ok
		sorry 'shortpass' unless params[:password].to_s.size >= 4
		ok, p = @db.call('set_password', p[:id], params[:password])
		ok, res = @db.call('cookie_from_id', p[:id], request.env['SERVER_NAME'])
		response.set_cookie('ok', value: res[:cookie], path: '/', httponly: true)
		redirect '/ayw/list'
	end

	# PASSWORD: forgot? form to enter email
	get '/forgot' do
		@bodyid = 'forgot'
		@pagetitle = 'forgot password'
		erb :forgot
	end

	# PASSWORD: email posted here. send password reset link
	post '/forgot' do
		ok, p = @db.call('get_person_email', params[:email])
		sorry 'emailnf' unless ok
		@db.call('make_newpass', p[:id])
		ok, b = @db.call('parsed_formletter', 1, p[:id])
		@db.call('new_email', p[:id], b[:body],
			"#{p[:address]} - your password reset link", 'derek@sivers')
		redirect '/thanks?for=reset'
	end

end
