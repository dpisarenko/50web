require 'sinatra/base'

require 'a50c/auth'
require 'a50c/sivers-comments'

class SiversCommentsWeb < Sinatra::Base

  configure do
    set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
    set :views, Proc.new { File.join(root, 'views/sivers-comments') }
  end

  helpers do
    def protected!
      redirect to('/login') unless has_cookie?
    end

    def has_cookie?
      request.cookies['api_key'] && request.cookies['api_pass']
    end
  end

  before do
    protected! unless ['/api_cookie', '/login'].include?(request.path_info)
    @sc = A50C::SiversComments.new(request.cookies['api_key'], request.cookies['api_pass'])
    @pagetitle = 'sivers-comments'
  end

  get '/login' do
    @pagetitle = 'log in'
    erb :login
  end

  post '/login' do
    redirect to('/login') unless params[:password] && (/\S+@\S+\.\S+/ === params[:email])
    a = A50C::Auth.new
    if res = a.auth(params[:email], params[:password])
      # TODO: domain: host
      response.set_cookie('api_key', value: res.key, path: '/', secure: true, httponly: true)
      response.set_cookie('api_pass', value: res.pass, path: '/', secure: true, httponly: true)
      redirect to('/')
    else
      redirect to('/login')
    end
  end

  get '/logout' do
    response.set_cookie('api_key', value: '', path: '/', expires: Time.at(0), secure: true, httponly: true)
    response.set_cookie('api_pass', value: '', path: '/', expires: Time.at(0), secure: true, httponly: true)
    redirect to('/login')
  end

  # TODO: remove if/when not needed
  post '/api_cookie' do
    if String(params[:api_key]).length == 8 && String(params[:api_pass]).length == 8
      response.set_cookie('api_key', value: params[:api_key], path: '/', secure: true, httponly: true)
      response.set_cookie('api_pass', value: params[:api_pass], path: '/', secure: true, httponly: true)
      redirect '/'
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

