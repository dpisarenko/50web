require_relative 'mod_auth'

require 'a50c/muckwork-client'

class MuckworkClientWeb < ModAuth

  configure do
    set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
    set :views, Proc.new { File.join(root, 'views/muckwork-client') }
  end

  helpers do
    def h(text)
      Rack::Utils.escape_html(text)
    end
  end

  before do
    @mc = A50C::MuckworkClient.new(request.cookies['api_key'], request.cookies['api_pass'])
    @client = @mc.get_client
  end

  get '/' do
    @pagetitle = 'Muckwork Client'
    erb :home
  end

  get '/account' do
    @pagetitle = @client.name
    erb :account
  end

  post '/account' do
    @mc.update_client(params)
    redirect to('/account')
  end

end

