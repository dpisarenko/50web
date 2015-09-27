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
		env['rack.errors'] = log
		if has_cookie?
			@mr = B50D::MuckWorker.new(request.cookies['api_key'], request.cookies['api_pass'])
			@worker = @mr.get_worker
		end
	end

	get '/' do
		@pagetitle = 'Muckwork'
		erb :home
	end

end

