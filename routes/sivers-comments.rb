require 'sinatra/base'

require 'a50c/sivers-comments'

class SiversCommentsWeb < Sinatra::Base

  configure do
    set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
    set :views, Proc.new { File.join(root, 'views/sivers-comments') }
    set :port, 7002
  end

  # TODO: https://developers.google.com/analytics/devguides/collection/analyticsjs/cross-domain
  use Rack::Auth::Basic, 'API key and pass' do |api_key, api_pass|
    api_key.size == 8 && api_pass.size == 8
  end

  before do
    #api_key, api_pass =  Rack::Auth::Basic::Request.new(request.env)
    @sc = A50C::SiversComments.new('aaaaaaaa', 'bbbbbbbb')
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

  run!
end

