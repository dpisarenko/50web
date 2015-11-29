require 'sinatra/base'
require 'b50d/getdb'

# https://data.sivers.org/ CONTENTS:
#	form to post your email to have password reset link emailed to you
# route to receive post of that ^ form, verify, send formletter, or sorry
# /thanks?for= and /sorry?for= pages
#	receive password reset link & show form to make new password
# route to receive post of new password. logs in with cookie. sends home.
# login form: email + password
# route to receive login form: sorry or logs in with cookie. sends home.
# home: forms for email, city/state/country, listype, urls. link to /now
# routes to receive post of each of these ^ forms
# now: if no now.urls yet, form to enter one
# route to trim new now.url, check unique, visit it, get long, insert
# now profile questions. edit link to turn answer into form. [save] button.
# routes to receive post of each of these ^ forms, redirect to /now

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
		livetest = (request.env['SERVER_NAME'].end_with? 'dev') ? 'test' : 'live'
		@db = getdb('peeps', livetest)
	end

	helpers do
		def h(text)
			Rack::Utils.escape_html(text)
		end
	end

	def sorry(msg)
		redirect to('/sorry?for=' + msg)
	end

	def thanks(msg)
		redirect to('/thanks?for=' + msg)
	end

	# Also checked by routes that don't require authorization because sometimes
	# people hit those by accident (browser back too far) even though they're
	# already logged in. So if they do, just send to authorized home.
	def authorized?
		return false unless /[a-zA-Z0-9]{32}:[a-zA-Z0-9]{32}/ === request.cookies['ok']
		ok, res = @db.call('get_person_cookie', request.cookies['ok'])
		return false unless ok
		@person_id = res[:id]
	end

	def authorize!
		redirect to('/login') unless authorized?
	end

	def login(person_id)
		ok, res = @db.call('cookie_from_id', person_id, 'data.sivers.org')
		logout unless ok
		response.set_cookie('ok', value: res[:cookie], path: '/',
			expires: Time.now + (60 * 60 * 24 * 30), secure: true, httponly: true)
	end

	def logout
		response.set_cookie('ok', value: '', path: '/',
			expires: Time.at(0), secure: true, httponly: true)
	end

##### ROUTES THAT DON'T NEED AUTH COOKIE

	#	form to post your email to have password reset link emailed to you
	get '/getpass' do
		redirect to('/') if authorized?
		@pagetitle = 'get a new password'
		erb :getpass
	end

	# route to receive post of that ^ form, verify, send formletter, or sorry
	post '/getpass' do
		redirect to('/') if authorized?
		sorry 'bademail' unless (/\A\S+@\S+\.\S+\Z/ === params[:email])
		ok, res = @db.call('reset_email', 1, params[:email])
		sorry 'unknown' unless ok
		thanks 'getpass'
	end

	# /thanks?for= and /sorry?for= pages
	get '/thanks' do
		@header = @pagetitle = 'Thank you!'
		@msg = case params[:for] 
		when 'getpass'
			'Please go check for an email from derek@sivers.org</p>
			<p>Subject is “your password reset link”'
		when 'that'
			'another message here'
		else
			'You’re so cool.'
		end
		erb :generic
	end

	# /thanks?for= and /sorry?for= pages
	get '/sorry' do
		@header = @pagetitle = 'Sorry!'
		@msg = case params[:for] 
		when 'bademail'
			'There was a typo in your email address.</p><p>Please try again.'
		when 'unknown'
			'That email address is not in my system.</p><p>Do you have another?'
		when 'badid'
			'That link is expired. Maybe try to <a href="/login">log in</a>?'
		when 'badpass'
			'Not sure why, but my system didn’t accept that password. Try another?'
		when 'badlogin'
			'That email address or password wasn’t right.</p>
			<p>Please <a href="/login">try again</a>.'
		else
			'I’m sure it’s my fault.'
		end
		erb :generic
	end

	#	receive password reset link & show form to make new password
	get %r{\A/newpass/([0-9]+)/([0-9a-zA-Z]{8})\Z} do |id, newpass|
		redirect to('/') if authorized?
		ok, @person = @db.call('get_person_newpass', id, newpass)
		sorry 'badid' unless ok
		@post2 = '/newpass/%d/%s' % [id, newpass]
		@pagetitle = 'make a password'
		erb :newpass
	end

	# route to receive post of new password. logs in with cookie. sends home.
	post %r{\A/newpass/([0-9]+)/([0-9a-zA-Z]{8})\Z} do |id, newpass|
		redirect to('/') if authorized?
		unless String(params[:setpass]).length > 3
			redirect to('/newpass/%d/%s' % [id, newpass])
		end
		ok, _ = @db.call('get_person_newpass', id, newpass)
		sorry 'badid' unless ok
		ok, _ = @db.call('set_password', id, params[:setpass])
		sorry 'badpass' unless ok
		login(id)
		redirect to('/')
	end

	# login form: email + password
	get '/login' do
		redirect to('/') if authorized?
		@pagetitle = 'login'
		erb :login
	end

	# route to receive login form: sorry or logs in with cookie. sends home.
	post '/login' do
		redirect to('/') if authorized?
		redirect to('/login') unless %r{} === params[:email]
		redirect to('/login') unless String(params[:password]).size > 3
		ok, p = @db.call('get_person_password', params[:email], params[:password])
		sorry 'badlogin' unless ok
		login p[:id]
		redirect to('/')
	end

##### ROUTES THAT NEED AUTH COOKIE:

	# home: forms for email, city/state/country, listype, urls. link to /now
	get '/' do
		authorize!
		# get their data
		@pagetitle = 'your data'
		erb :home
	end

	# routes to receive post of each of these ^ forms...
	# update email, city, state, country, listype
	post '/update' do
		authorize!
		# TODO: whitelist update-able params
		ok, _ = @db.call('update_person', @person_id, params)
		# TODO: log change in core.changes
		sorry 'badupdate' unless ok
		redirect to('/?update=ok')
	end

	# delete a url
	post %r{\A/urls/delete/([0-9]+)\Z} do |id|
		authorize!
		# delete url
		redirect to('/')
	end

	# add a url
	post '/urls' do
		authorize!
		# add url
		# log in core.changes
		redirect to('/')
	end

	# now: if no now.urls yet, form to enter one
	get '/now' do
		authorize!
		@pagetitle = ''
		erb :now
	end

	# route to trim new now.url, check unique, visit it, get long, insert
	post '/now' do
		authorize!
		# add now.url
		# log in core.changes
		redirect to('/now')
	end

	# now profile questions. edit link to turn answer into form. [save] button.
	get '/now_profile' do
		authorize!
		@pagetitle = ''
		erb :now_profile
	end

	# routes to receive post of each of these ^ forms, redirect to /now
	post '/now_profile' do
		authorize!
		# whitelist of stats to update
		# update or add stat
		# log in core.changes
		redirect to('/now')
	end

	# log out
	get '/logout' do
		logout
		redirect to('/')
	end
end
