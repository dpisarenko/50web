require 'sinatra/base'

require 'a50c/sivers-comments'

class SiversCommentsWeb < Sinatra::Base

  configure do
    set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
    set :views, Proc.new { File.join(root, 'views/sivers-comments') }
  end

  helpers do
    def protected!
      unless has_cookie?
        halt 401  # TODO: go to 50.io login page
      end
    end

    def has_cookie?
      request.cookies['api_key'] && request.cookies['api_pass']
    end
  end

  before do
    protected! unless request.path_info == '/api_cookie'
    @sc = A50C::SiversComments.new(request.cookies['api_key'], request.cookies['api_pass'])
    @pagetitle = 'sivers-comments'
  end

  post '/api_cookie' do
    if String(params[:api_key]).length == 8 && String(params[:api_pass]).length == 8
      # TODO: domain, SSL, expiration
      response.set_cookie('api_key', value: params[:api_key], path: '/')
      response.set_cookie('api_pass', value: params[:api_pass], path: '/')
      redirect '/'
    else
      redirect 'https://50.io/'  # TODO: dev domain?
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

