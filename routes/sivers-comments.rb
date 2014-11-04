require 'sinatra/base'

require 'a50c/sivers-comments'

class SiversCommentsWeb < Sinatra::Base

  configure do
    set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
    set :views, Proc.new { File.join(root, 'views/sivers-comments') }
    set :port, 7002
  end

  helpers do
    def auth!
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == ['aaaaaaaa', 'bbbbbbbb']
    end
  end

  before do
    auth!
    api_key = @auth.credentials[0]
    api_pass = @auth.credentials[1]
    @sc = A50C::SiversComments.new(api_key, api_pass)
    @pagetitle = 'sivers comments'
  end

  get '/' do
    @comments = @sc.get_comments
    erb :home
  end

  run!
end

