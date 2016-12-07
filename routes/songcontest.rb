require 'sinatra/base'
require 'getdb'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'sinatra/config_file'

class SongContest < Sinatra::Base
	register Sinatra::ConfigFile

	log = File.new('/home/dp/dev/50web/servers/dev/SongContest.log', 'a+')
	log.sync = true

	config_file '/home/dp/dev/50web/servers/dev/songcontest.yml'

	configure do
		enable :logging
		use Rack::Logger
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new {File.join(root, 'views/songcontest')}
		I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
		I18n.load_path = Dir[File.join(settings.root, 'i18n/songcontest', '*.yml')]
		I18n.backend.load_translations
	end

	before do
		env['rack.errors'] = log
		logger.info 'settings.dbname: ' + settings.dbname
		Object.const_set(:DB, PG::Connection.new(
			dbname: settings.dbname, 
			user: settings.user, 
			password: settings.password, 
			host: settings.host,
			port: settings.port
			)
		)
		@db = getdb('songcontest')
		@peepsdb = getdb('peeps')
	end

	before '/:locale/*' do
	  I18n.locale       =       params[:locale]
	  request.path_info = '/' + params[:splat ][0]
	end

	helpers do
	  def find_template(views, name, engine, &block)
	    I18n.fallbacks[I18n.locale].each { |locale|
	      super(views, "#{name}.#{locale}", engine, &block) }
	    super(views, name, engine, &block)
	  end
		def logger
		    request.logger
		end	  
	end	

	def login(person_id)
		ok, res = @peepsdb.call('cookie_from_id', person_id, 'localhost')
		logout unless ok
		response.set_cookie('ok', value: res[:cookie], path: '/',
			expires: Time.now + (60 * 60 * 24 * 30), secure: false, httponly: false)
	end

	def logout
		response.set_cookie('ok', value: '', path: '/',
			expires: Time.at(0), secure: true, httponly: true)
	end
	
	def sorry(msg)
		redirect to('/sorry?for=' + msg)
	end
	
	def authorized?
		# logger.info 'Cookie: ' + request.cookies['ok']
		logger.info 'Cookie: ' + request.cookies['ok'] unless request.cookies['ok'] === nil
		return false unless /[a-zA-Z0-9]{32}:[a-zA-Z0-9]{32}/ === request.cookies['ok']
		logger.info 'Cookie: ' + request.cookies['ok']
		ok, res = @peepsdb.call('get_person_cookie', request.cookies['ok'])
		if ok
			@person_id = res[:id]
			ok2, attrs = @peepsdb.call('person_attributes', @person_id)
			@isMusician = attrs.select { |x| (x[:atkey] == 'Musician') && x[:plusminus]}.count > 0
			logger.info 'isMusician: ' + @isMusician.to_s
		end
		return false unless ok
	end
	
	def authorize!
		redirect to('/' + I18n.locale.to_s + '/') unless authorized?
	end	

	get '/' do
		logger.info 'Logging test'
		erb :home
	end

	get '/sorry' do
		@header = @pagetitle = 'Sorry!'
		@msg = case params[:for] 
		when 'bademail'
			I18n.t 'sorry_bademail'
		when 'unknown'
			I18n.t 'sorry_unknownemail'
		when 'badid'
			(I18n.t 'sorry_badid') % "#{I18n.locale}"
		when 'badpass'
			I18n.t 'sorry_badpass'
		when 'badlogin'
			(I18n.t 'sorry_badlogin') % "#{I18n.locale}"
		when 'badupdate'
			I18n.t 'sorry_badupdate'
		else
			I18n.t 'sorry_unknown'
		end
		erb :generic
	end

	post '/signup' do
		# TODO: Do all sorts of verifications
		ok, res = @peepsdb.call('create_person', params['name'], params['email'])
		@peepsdb.call('set_password', res[:id], params['password'])
		if ((params['type'] == 'fan') || (params['type'] == 'musician'))
			@peepsdb.call('person_set_attribute', res[:id], params['type'], true)
		end
		locale = request.path.split('/').first
		redirect to('/' + I18n.locale.to_s + '/signup-success')
	end

	get '/signup-success' do
		erb :signup_success
	end

	# route to receive login form: sorry or logs in with cookie. sends home.
	post '/login' do
		redirect to('/') if authorized?
		logger.info 'Params, password: ' + params[:password]
		sorry 'bademail' unless (/\A\S+@\S+\.\S+\Z/ === params[:email])
		sorry 'badlogin' unless String(params[:password]).size > 3
		logger.info 'Params, email: ' + params[:email]
		ok, p = @peepsdb.call('get_person_password', params[:email], params[:password])
		sorry 'badlogin' unless ok
		login p[:id]
		# redirect to('/')
		redirect to('/' + I18n.locale.to_s + '/main')
	end

	def musician?
	end
	
	get '/main' do
		authorize!
		erb :main
	end
	
	get '/logout' do
		logout
		redirect to('/' + I18n.locale.to_s + '/')
	end

	get '/upload' do
		authorize!
		erb :upload
	end

	post "/upload" do
		authorize!
		ok, songRec = @db.call('create_song', @person_id)  
		File.open('../../public/songs/song' + songRec[:id].to_s + '.mp3', "wb") do |f|
			f.write(params['song'][:tempfile].read)
		end	  
		erb :main
	end

	get '/playback' do
		authorize!
		erb :playback
	end
end
