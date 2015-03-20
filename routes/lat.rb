require 'sinatra/base'
require 'b50d/lat'

class Lat < Sinatra::Base

	log = File.new('/tmp/Lat.log', 'a+')
	log.sync = true

	helpers do
		def h(text)
			Rack::Utils.escape_html(text)
		end
	end

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/lat') }
	end

	before do
		env['rack.errors'] = log
		@l = B50D::Lat.new
	end

	get '/' do
		erb :home
	end
end
