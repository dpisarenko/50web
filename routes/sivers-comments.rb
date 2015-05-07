require_relative 'mod_auth'
require 'b50d-config.rb'  # INP
require 'b50d/sivers-comments'

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
		if String(request.cookies['api_key']).size == 8 && String(request.cookies['api_pass']).size == 8
			@sc = B50D::SiversComments.new(request.cookies['api_key'], request.cookies['api_pass'], @livetest)
		end
	end

	get '/' do
		@comments = @sc.get_comments
		erb :home
	end

	get %r{\A/comment/([0-9]+)\Z} do |id|
		@comment = @sc.get_comment(id) || halt(404)
		erb :edit
	end

	get %r{\A/person/([0-9]+)/comments\Z} do |id|
		@comments = @sc.comments_by_person(id)
		erb :home
	end

	post %r{\A/comment/([0-9]+)\Z} do |id|
		@sc.update_comment(id, params)
		redirect '/'
	end

	post %r{\A/comment/([0-9]+)/reply\Z} do |id|
		@sc.reply_to_comment(id, params[:reply])
		redirect '/'
	end

	post %r{\A/comment/([0-9]+)/delete\Z} do |id|
		@sc.delete_comment(id)
		redirect '/'
	end

	post %r{\A/comment/([0-9]+)/spam\Z} do |id|
		@sc.spam_comment(id)
		redirect '/'
	end
end

