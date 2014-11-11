require 'sinatra/base'

require 'a50c/peep'

class Inbox < Sinatra::Base

  configure do
    set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
    set :views, Proc.new { File.join(root, 'views/inbox') }
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

    def h(text)
      Rack::Utils.escape_html(text)
    end

    def redirect_to_email_or_person(email_id, person_id)
      if email_id
        redirect to('/email/%d' % email_id)
      else
        redirect to('/person/%d' % person_id)
      end
    end

    def redirect_to_email_or_home(email)
      if email
        redirect to('/email/%d' % email.id)
      else
        redirect to('/')
      end
    end
  end

  before do
    protected! unless request.path_info == '/api_cookie'
    @p = A50C::Peep.new(request.cookies['api_key'], request.cookies['api_pass'])
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
    @unopened_email_count = @p.unopened_email_count
    @open_emails = @p.open_emails
    @unknowns_count = @p.unknowns_count['count']
    @pagetitle = 'inbox'
    erb :home
  end

  get '/unknown' do
    @unknown = @p.next_unknown
    redirect to('/') unless @unknown
    @search = (params[:search]) ? params[:search] : nil
    @results = @p.person_search(@search) if @search
    @pagetitle = 'unknown'
    erb :unknown
  end
 
  post %r{\A/unknown/([0-9]+)\Z} do |email_id|
    if params[:person_id]
      @p.unknown_is_person(email_id, params[:person_id])
    else
      @p.unknown_is_new_person(email_id)
    end
    redirect to('/unknown')
  end

  post %r{\A/unknown/([0-9]+)/delete\Z} do |email_id|
    @p.delete_unknown(email_id)
    redirect to('/unknown')
  end

  get '/unopened' do
    @emails = @p.emails_unopened(params[:profile], params[:category])
    @pagetitle = 'unopened for %s: %s' % [params[:profile], params[:category]]
    erb :emails
  end

  post '/next_unopened' do
    email = @p.next_unopened_email(params[:profile], params[:category])
    redirect_to_email_or_home(email)
  end

  get %r{\A/email/([0-9]+)\Z} do |id|
    @email = @p.open_email(id) || halt(404)
    @person = @p.get_person(@email.person.id)
    @profiles = @p.profiles
    @pagetitle = 'email %d' % id
    erb :email
  end

  post %r{\A/email/([0-9]+)\Z} do |id|
    @p.update_email(id, params)
    redirect to('/email/%d' % id)
  end

  post %r{\A/email/([0-9]+)/delete\Z} do |id|
    @p.delete_email(id)
    redirect '/'
  end

  post %r{\A/email/([0-9]+)/unread\Z} do |id|
    @p.unread_email(id)
    redirect '/'
  end

  post %r{\A/email/([0-9]+)/close\Z} do |id|
    @p.close_email(id)
    email = @p.next_unopened_email(params[:profile], params[:category])
    redirect_to_email_or_home(email)
  end

  post %r{\A/email/([0-9]+)/reply\Z} do |id|
    @p.reply_to_email(id, params[:reply])
    email = @p.next_unopened_email(params[:profile], params[:category])
    redirect_to_email_or_home(email)
  end

  post %r{\A/email/([0-9]+)/not_my\Z} do |id|
    @p.not_my_email(id)
    redirect '/'
  end

  post '/person' do
    person = @p.new_person(params[:name], params[:email])
    redirect to('/person/%d' % person.id)
  end

  get %r{\A/person/([0-9]+)\Z} do |id|
    @person = @p.get_person(id) || halt(404)
    @emails = @p.emails_for_person(id).reverse
    @profiles = @p.profiles
    @pagetitle = 'person %d' % id
    erb :personfull
  end

  post %r{\A/person/([0-9]+)\Z} do |id|
    @p.update_person(id, params)
    redirect_to_email_or_person(params[:email_id], id)
  end

  post %r{\A/person/([0-9]+)/url\Z} do |id|
    @p.add_url(id, params[:url])
    redirect_to_email_or_person(params[:email_id], id)
  end

  post %r{\A/person/([0-9]+)/stat\Z} do |id|
    @p.add_stat(id, params[:key], params[:value])
    redirect_to_email_or_person(params[:email_id], id)
  end

  post %r{\A/person/([0-9]+)/email\Z} do |id|
    @p.new_email_to(id, params[:body], params[:subject], params[:profile])
    redirect to('/person/%d' % id)
  end

  post %r{\A/url/([0-9]+)/delete\Z} do |id|
    @p.delete_url(id)
    redirect_to_email_or_person(params[:email_id], params[:person_id])
  end

  post %r{\A/stat/([0-9]+)/delete\Z} do |id|
    @p.delete_stat(id)
    redirect_to_email_or_person(params[:email_id], params[:person_id])
  end

  post %r{\A/url/([0-9]+)\Z} do |id|
    @p.star_url(id) if params[:star] == 't'
    @p.unstar_url(id) if params[:star] == 'f'
    @p.update_url(id, params[:url]) if params[:url]
    redirect_to_email_or_person(params[:email_id], params[:person_id])
  end

  # to avoid external sites seeing my internal links:
  # <a href="/link?url=http://someothersite.com">someothersite.com</a>
  get '/link' do
    redirect to(params[:url])
  end

  get '/search' do
    @q = (params[:q]) ? params[:q] : false
    @results = @p.person_search(@q) if @q
    @pagetitle = 'search'
    erb :search
  end

end

