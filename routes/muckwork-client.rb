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
    if has_cookie?
      @mc = A50C::MuckworkClient.new(request.cookies['api_key'], request.cookies['api_pass'])
      @client = @mc.get_client
    end
  end

  get '/' do
    @pagetitle = 'Muckwork Client'
    @projects = @mc.get_projects
    @payments = @mc.payments
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

  get %r{\A/project/([0-9]+)\Z} do |id|
    @project = @mc.get_project(id)
    redirect to('/') unless @project
    @pagetitle = @project.title
    erb :project
  end

  post %r{\A/project/([0-9]+)/approve\Z} do |id|
    @mc.approve_project(id)
    redirect to("/project/#{id}")
  end

  post %r{\A/project/([0-9]+)\Z} do |id|
    @mc.update_project(id, params[:title], params[:description])
    redirect to("/project/#{id}")
  end

  post '/projects' do
    p = @mc.create_project(params[:title], params[:description])
    if p
      redirect to("/project/#{p.id}")
    else
      redirect to('/')
    end
  end

  get %r{\A/payment/([0-9]+)\Z} do |id|
    @payment = @mc.payment(id)
    redirect to('/') unless @payment
    @pagetitle = 'payment %d' % id
    erb :payment
  end

end

