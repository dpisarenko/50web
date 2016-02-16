require 'sinatra/base'
require 'getdb'
require 'i18n'
require 'i18n/backend/fallbacks'


class SongContest < Sinatra::Base

	log = File.new('/tmp/SongContest.log', 'a+')
	log.sync = true

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
		# TODO: Put the connection credentials to the right place
		Object.const_set(:DB, PG::Connection.new(
			dbname: 'd50b', 
			user: 'd50b', 
			password: 'postgres', 
			host: 'localhost',
			port: '5432'
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
		ok, res = @db.call('cookie_from_id', person_id, 'data.sivers.org')
		logout unless ok
		response.set_cookie('ok', value: res[:cookie], path: '/',
			expires: Time.now + (60 * 60 * 24 * 30), secure: true, httponly: true)
	end

	def authorized?
		return false unless /[a-zA-Z0-9]{32}:[a-zA-Z0-9]{32}/ === request.cookies['ok']
		ok, res = @db.call('get_person_cookie', request.cookies['ok'])
		return false unless ok
		@person_id = res[:id]
	end

	get '/' do
		logger.info 'Logging test'
		erb :home
	end

	post '/signup' do
		# TODO: Do all sorts of verifications
		ok, res = @peepsdb.call('create_person', params['name'], params['email'])
		logger.info 'Params, password: ' + params['password']
		@peepsdb.call('set_password', res, params['password'])
		locale = request.path.split('/').first
		redirect to('/' + I18n.locale.to_s + '/signup-success')
	end

	get '/signup-success' do
		erb :signup_success
	end

	# route to receive login form: sorry or logs in with cookie. sends home.
	post '/login' do
		redirect to('/') if authorized?
		sorry 'bademail' unless (/\A\S+@\S+\.\S+\Z/ === params[:email])
		sorry 'badlogin' unless String(params[:password]).size > 3
		ok, p = @db.call('get_person_password', params[:email], params[:password])
		sorry 'badlogin' unless ok
		login p[:id]
		redirect to('/')
	end

	get '/main' do
		authorize!
		erb :main
	end

end
