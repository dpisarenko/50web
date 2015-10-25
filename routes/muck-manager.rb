require_relative 'mod_auth'
require_relative '../lib/db2js.rb'

class MuckManagerWeb < ModAuth

	log = File.new('/tmp/MuckManagerWeb.log', 'a+')
	log.sync = true

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/muck-manager') }
	end

	helpers do
		def h(text)
			Rack::Utils.escape_html(text)
		end
	end

	before do
		env['rack.errors'] = log
		if has_cookie?
			@db = getdm('muckwork', @livetest)
			@manager = @db.call('get_manager', @manager_id)
		end
	end

	get '/' do
		#TODO get projects: unstarted, unquoted, unfinished
		#TODO get tasks: unstarted, unquoted, unfinished
		@pagetitle = 'Muckwork Manager'
		erb :home
	end

end
