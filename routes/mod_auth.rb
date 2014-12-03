require 'sinatra/base'
require 'a50c/auth'

class ModAuth < Sinatra::Base

  helpers do
    def protected!
      redirect to('/login') unless has_cookie?
    end

    def has_cookie?
      request.cookies['api_key'] && request.cookies['api_pass']
    end
  end

  before do
    protected! unless ['/login'].include?(request.path_info)
  end

  get '/login' do
    @pagetitle = 'log in'
    erb :login
  end

  post '/login' do
    redirect to('/login') unless params[:password] && (/\S+@\S+\.\S+/ === params[:email])
    a = A50C::Auth.new
    if res = a.auth(params[:email], params[:password])
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

end
