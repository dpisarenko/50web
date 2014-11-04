require 'sinatra/base'

require 'a50c/sivers-comments'

class SiversCommentsWeb < Sinatra::Base

  configure do
    set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
    set :views, Proc.new { File.join(root, 'views/sivers-comments') }
    set :port, 7002
  end

  before do
    # AUTH HERE
    @sc = A50C::MusicThoughts.new(api_key, api_pass)
  end

  get '/' do
    @comments = @sc.get_comments
    erb :home
  end

  run!
end

