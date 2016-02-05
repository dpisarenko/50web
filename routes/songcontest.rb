require 'sinatra/base'
require 'getdb'

class SongContest < Sinatra::Base

	log = File.new('/tmp/SongContest.log', 'a+')
	log.sync = true


	before do
		env['rack.errors'] = log
		@db = getdb('songcontest')
	end

	get '/' do
		erb :home
	end
end
