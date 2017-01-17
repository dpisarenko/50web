require 'sinatra/base'
require 'getdb'
require 'i18n'
require 'i18n/backend/fallbacks'
require 'sinatra/config_file'

class SongContest < Sinatra::Base
	register Sinatra::ConfigFile

	log = File.new('/Users/guywarburg/Programming/Songtest/50web/servers/dev/SongContest.log', 'a+')
	log.sync = true

	config_file '/Users/guywarburg/Programming/Songtest/50web/servers/dev/songcontest2.yml'

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
		return false unless /[a-zA-Z0-9]{32}:[a-zA-Z0-9]{32}/ === request.cookies['ok']
		ok, res = @peepsdb.call('get_person_cookie', request.cookies['ok'])
		return false unless ok
		@person_id = res[:id]
		ok2, attrs = @peepsdb.call('person_attributes', @person_id)
		@isMusician = attrs.select { |x| (x[:atkey] == 'musician') && x[:plusminus]}.count > 0
		@isFan = attrs.select { |x| (x[:atkey] == 'fan') && x[:plusminus]}.count > 0
		return true
	end
	
	def authorize!
		redirect to('/' + I18n.locale.to_s + '/') unless authorized?
	end	

	def musician?
		return @isMusician
	end
	
	def fan?
		return @isFan
	end
	
	def authorizeMusician!
		redirect to('/' + I18n.locale.to_s + '/') unless authorized? && musician?
	end
	
	def authorizeFan!
		redirect to('/' + I18n.locale.to_s + '/') unless authorized? && fan?
	end	
	
	get '/' do
		# logger.info 'Logging test'
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
		when 'badfiletype'
			I18n.t 'sorry_badfiletype'
		when 'badpassnomatch'
			I18n.t 'sorry_badpassnomatch'
		when 'badpasstooshort'
			I18n.t 'sorry_badpasstooshort'
		when 'nosongs'
			I18n.t 'sorry_nosongs'
		when 'nograde'
			I18n.t 'sorry_nograde'
		when 'nocomment'
			I18n.t 'sorry_nocomment'
		when 'nosong'
			I18n.t 'sorry_nosong'
		when 'nostats'
			I18n.t 'sorry_nostats'
		when 'badsong'
			I18n.t 'sorry_badsong'
		else
			I18n.t 'sorry_unknown'
		end
		erb :generic
	end

	post '/signup' do
		sorry 'bademail' unless (/\A\S+@\S+\.\S+\Z/ === params['email'])
		sorry 'badpassnomatch' unless (params['password'] === params['password2'])
		sorry 'badpasstooshort' unless (params['password'].length > 3)		
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
		sorry 'bademail' unless (/\A\S+@\S+\.\S+\Z/ === params[:email])
		sorry 'badlogin' unless String(params[:password]).size > 3
		ok, p = @peepsdb.call('get_person_password', params[:email], params[:password])
		sorry 'badlogin' unless ok
		login p[:id]
		redirect to('/' + I18n.locale.to_s + '/main')
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
		authorizeMusician!
		erb :upload
	end

	post "/upload" do
		authorizeMusician!
		sorry 'badfiletype' unless params['song'][:type].to_s == 'audio/mp3'
		ok, songRec = @db.call('create_song', @person_id, params['name'])  
		File.open('../../public/songs/song' + songRec[:id].to_s + '.mp3', "wb") do |f|
			f.write(params['song'][:tempfile].read)
		end	  
		erb :upload_success
	end

	get '/playback' do
		authorizeFan!
		logger.info '@person_id: ' + @person_id.to_s
		ok, songRec = @db.call('find_song', @person_id)
		sorry 'nosongs' unless not songRec[:id].nil?
		@songPath = '/songs/song' + songRec[:id].to_s + '.mp3'
		@songId = songRec[:id].to_s
		erb :playback
	end
	
	post '/save_feedback' do
		authorizeFan!
		sorry 'nograde' unless not params['grade'].nil?
		grade = params['grade'].to_i
		sorry 'nograde' unless (grade >= 1) && (grade <= 5)
		comment = params['comment'].strip
		sorry 'nocomment' unless comment.length >= 50
		song_id = params['song_id'].to_i
		sorry 'nosong' unless song_id > 0
		ok, res = @db.call('create_feedback', @person_id, song_id, grade, comment)
		redirect to('/' + I18n.locale.to_s + '/playback')
	end
	
	get '/stats' do
		authorizeMusician!
		ok, statsCount = @db.call('song_stats_count', @person_id)
		sorry 'nostats' unless statsCount[:calculate_song_stats_count].to_i > 0
		ok, @stats = @db.call('all_songs_stats', @person_id)
		erb :stats
	end
	
	get '/song_comments' do
		authorizeMusician!
		logger.info 'songId: ' + params['song']
		songId = params['song'].to_i
		sorry 'badsong' unless songId > 0
		ok, songNameRec = @db.call('song_name', @person_id, songId)
		logger.info 'songNameRec: ' + songNameRec.to_s
		@songName = songNameRec[:compose_song_name]
		ok, @comments = @db.call('song_comments', @person_id, songId)
		logger.info '@comments: ' + @comments.to_s
		erb :song_comments
	end
end
