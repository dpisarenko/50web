require_relative 'mod_auth'

require 'b50d/muckwork'

class MuckWorkerWeb < ModAuth

	log = File.new('/tmp/MuckWorkerWeb.log', 'a+')
	log.sync = true

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/muck-worker') }
	end

	helpers do
		def h(text)
			Rack::Utils.escape_html(text)
		end
	end

	before do
		@api = 'Muckworker'
		@livetest = 'test'
		env['rack.errors'] = log
		if String(request.cookies['api_key']).size == 8 && String(request.cookies['api_pass']).size == 8
			@mr = B50D::Muckworker.new(request.cookies['api_key'], request.cookies['api_pass'], @livetest)
			@worker = @mr.get_worker
		end
	end

	get '/' do
		@pagetitle = 'Muckwork'
		erb :home
	end

end

