require 'sinatra/base'
require 'getdb'

class SongContest < Sinatra::Base

	log = File.new('/tmp/SongContest.log', 'a+')
	log.sync = true

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new {File.join(root, 'views/songcontest')}
	end


	before do
		env['rack.errors'] = log
		# @db = getdb('songcontest')
	end

	get '/' do
		erb :home
	end
end
