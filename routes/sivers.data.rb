require_relative 'mod_auth'

class SiversData < ModAuth

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
	end

	get '/' do
		erb :home
	end

end
