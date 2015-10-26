require_relative 'mod_auth'
require 'b50d/getdb'
require 'b50d-config.rb'  # INP

class SiversComments < ModAuth

	log = File.new('/tmp/SiversComments.log', 'a+')
	log.sync = true

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/sivers-comments') }
	end

	before do
		env['rack.errors'] = log
		@api = 'SiversComments'
		@livetest = 'live' # (/dev$/ === request.env['SERVER_NAME']) ? 'test' : 'live'
		@db = getdb('sivers', @livetest)
	end

	get '/' do
		ok, @comments = @db.call('new_comments')
		erb :home
	end

	get %r{\A/comment/([0-9]+)\Z} do |id|
		ok, @comment = @db.call('get_comment', id)
		halt(404) unless ok
		erb :edit
	end

	get %r{\A/person/([0-9]+)/comments\Z} do |id|
		ok, @comments = @db.call('comments_by_person', id)
		halt(404) unless ok
		erb :home
	end

	post %r{\A/comment/([0-9]+)\Z} do |id|
		@db.call('update_comment', id, params.to_json)
		redirect '/'
	end

	post %r{\A/comment/([0-9]+)/reply\Z} do |id|
		@db.call('reply_to_comment', id, params[:reply])
		redirect '/'
	end

	post %r{\A/comment/([0-9]+)/delete\Z} do |id|
		@db.call('delete_comment', id)
		redirect '/'
	end

	post %r{\A/comment/([0-9]+)/spam\Z} do |id|
		@db.call('spam_comment', id)
		redirect '/'
	end
end

