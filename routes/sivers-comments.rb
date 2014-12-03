require_relative 'mod_auth'

require 'a50c/sivers-comments'

class SiversCommentsWeb < ModAuth

  configure do
    set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
    set :views, Proc.new { File.join(root, 'views/sivers-comments') }
  end

  before do
    @sc = A50C::SiversComments.new(request.cookies['api_key'], request.cookies['api_pass'])
    @pagetitle = 'sivers-comments'
  end

  get '/' do
    @comments = @sc.get_comments
    erb :home
  end

  get %r{\A/comment/([0-9]+)\Z} do |id|
    @comment = @sc.get_comment(id) || halt(404)
    erb :edit
  end

  post %r{\A/comment/([0-9]+)\Z} do |id|
    @sc.update_comment(id, params[:html])
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

