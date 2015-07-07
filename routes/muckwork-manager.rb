require_relative 'mod_auth'

require 'b50d/muckwork-manager'

class MuckworkManager < ModAuth

	log = File.new('/tmp/MuckworkManager.log', 'a+')
	log.sync = true

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/muckwork-manager') }
	end

	helpers do
		def h(text)
			Rack::Utils.escape_html(text)
		end
	end

	before do
		env['rack.errors'] = log
		if has_cookie?
			@mm = B50D::MuckworkManager.new(request.cookies['api_key'], request.cookies['api_pass'])
			@manager = @mm.get_manager
		end
	end

	get '/' do
		#TODO get projects: unstarted, unquoted, unfinished
		#TODO get tasks: unstarted, unquoted, unfinished
		@pagetitle = 'Muckwork Manager'
		erb :home
	end

