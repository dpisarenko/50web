require 'sinatra/base'

require 'a50c/sivers-comments'

class SiversCommentsWeb < Sinatra::Base

  configure do
    set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
    set :views, Proc.new { File.join(root, 'views/sivers-comments') }
    set :port, 7002
  end

  # TODO: https://developers.google.com/analytics/devguides/collection/analyticsjs/cross-domain
  use Rack::Auth::Basic, "API key and pass" do |api_key, api_pass|
    api_key.size == 8 && api_pass.size == 8
  end

  before do
    api_key, api_pass =  Rack::Auth::Basic::Request.new(request.env)
    @sc = A50C::SiversComments.new(api_key, api_pass)
    @pagetitle = 'sivers comments'
  end

  get '/' do
    @comments = @sc.get_comments
    erb :home
  end

  run!
end

