require 'sinatra/base'
require 'getdb'
require 'i18n'
require 'i18n/backend/fallbacks'

class SongContest < Sinatra::Base

	log = File.new('/tmp/SongContest.log', 'a+')
	log.sync = true

	configure do
		enable :logging
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
	end	

	get '/' do
		erb :home
	end

	post '/signup' do
		# TODO: Do all sorts of verifications
		ok, res = @peepsdb.call('create_person', params['name'], params['email'])
		@peepsdb.call('set_password', res, params['password'])
		# redirect to('/' + request.path_info + '/signup-success')
		redirect to('/signup-success')
	end

	get '/signup-success' do
		erb :signup_success
	end
end
