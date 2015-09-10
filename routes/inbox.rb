require_relative 'mod_auth'
require 'b50d-config.rb'  # SCP

class Inbox < ModAuth

	log = File.new('/tmp/Inbox.log', 'a+')
	log.sync = true

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/inbox') }
	end

	helpers do
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
				redirect to('/email/%d' % email[:id])
			else
				redirect to('/')
			end
		end
	end

	before do
		env['rack.errors'] = log
		# shared ModAuth requires @api and @livetest:
		@api = 'Peep'
		@livetest = 'live' # (/dev$/ === request.env['SERVER_NAME']) ? 'test' : 'live'
		if String(request.cookies['api_key']).size == 8 && String(request.cookies['api_pass']).size == 8
			@p = B50D::Peeps.new(request.cookies['api_key'], request.cookies['api_pass'], @livetest)
		end
	end

	get '/' do
		@unopened_email_count = @p.unopened_email_count
		@open_emails = @p.open_emails
		@unknowns_count = @p.unknowns_count[:count]
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
 
	post %r{^/unknown/([0-9]+)$} do |email_id|
		if params[:person_id]
			@p.unknown_is_person(email_id, params[:person_id])
		else
			@p.unknown_is_new_person(email_id)
		end
		redirect to('/unknown')
	end

	post %r{^/unknown/([0-9]+)/delete$} do |email_id|
		@p.delete_unknown(email_id)
		redirect to('/unknown')
	end

	get '/unopened' do
		@emails = @p.emails_unopened(params[:profile], params[:category])
		@pagetitle = 'unopened for %s: %s' % [params[:profile], params[:category]]
		erb :emails
	end

	get '/unemailed' do
		@people = @p.unemailed_people
		@pagetitle = 'unemailed'
		erb :people
	end

	post '/next_unopened' do
		email = @p.next_unopened_email(params[:profile], params[:category])
		redirect_to_email_or_home(email)
	end

	get %r{^/email/([0-9]+)$} do |id|
		@email = @p.open_email(id) || halt(404)
		@person = @email[:person]
		@clash = (@email[:their_email] != @person[:email])
		@profiles = @p.profiles
		@formletters = @p.formletters
		@locations = @p.all_countries
		@reply = (params[:formletter]) ?
			@p.get_formletter_for_person(params[:formletter], @email[:person][:id])[:body] : ''
		@pagetitle = 'email %d from %s' % [id, @person[:name]]
		erb :email
	end

	post %r{^/email/([0-9]+)$} do |id|
		@p.update_email(id, params)
		redirect to('/email/%d' % id)
	end

	post %r{^/email/([0-9]+)/delete$} do |id|
		@p.delete_email(id)
		redirect '/'
	end

	post %r{^/email/([0-9]+)/unread$} do |id|
		@p.unread_email(id)
		redirect '/'
	end

	post %r{^/email/([0-9]+)/close$} do |id|
		@p.close_email(id)
		email = @p.next_unopened_email(params[:profile], params[:category])
		redirect_to_email_or_home(email)
	end

	post %r{^/email/([0-9]+)/reply$} do |id|
		@p.reply_to_email(id, params[:reply])
		email = @p.next_unopened_email(params[:profile], params[:category])
		redirect_to_email_or_home(email)
	end

	post %r{^/email/([0-9]+)/not_my$} do |id|
		@p.not_my_email(id)
		redirect '/'
	end

	post '/person' do
		person = @p.new_person(params[:name], params[:email])
		redirect to('/person/%d' % person[:id])
	end

	get %r{^/person/([0-9]+)$} do |id|
		@person = @p.get_person(id) || halt(404)
		@emails = @p.emails_for_person(id).reverse
		@tables = @p.tables_with_person(id).sort
		@tables.map! do |t|
			(t == 'sivers.comments') ?
				('<a href="' + (SCP % id) + '">sivers.comments</a>') : t
		end
		@profiles = @p.profiles
		@locations = @p.all_countries
		@pagetitle = 'person %d = %s' % [id, @person[:name]]
		erb :personfull
	end

	post %r{^/person/([0-9]+)$} do |id|
		@p.update_person(id, params)
		redirect_to_email_or_person(params[:email_id], id)
	end

	post %r{^/person/([0-9]+)/annihilate$} do |id|
		@p.annihilate_person(id)
		redirect '/'
	end

	post %r{^/person/([0-9]+)/url.json$} do |id|
		@p.add_url(id, params[:url]).to_json
	end

	post %r{^/person/([0-9]+)/stat.json$} do |id|
		@p.add_stat(id, params[:key], params[:value]).to_json
	end

	post %r{^/person/([0-9]+)/email$} do |id|
		@p.new_email_to(id, params[:body], params[:subject], params[:profile])
		redirect to('/person/%d' % id)
	end

	post %r{^/person/([0-9]+)/match/([0-9]+)$} do |person_id, email_id|
		e = @p.open_email(email_id)
		@p.update_person(person_id, {email: e[:their_email]})
		redirect to('/email/%d' % email_id)
	end

	post %r{^/url/([0-9]+)/delete.json$} do |id|
		@p.delete_url(id).to_json
	end

	post %r{^/stat/([0-9]+)/delete.json$} do |id|
		@p.delete_stat(id).to_json
	end

	post %r{^/url/([0-9]+).json$} do |id|
		if params[:star] == 't'
			@p.star_url(id).to_json
		elsif params[:star] == 'f'
			@p.unstar_url(id).to_json
		end
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

	get %r{^/sent/([0-9]+)$} do |howmany|
		@emails = @p.sent_emails(howmany)
		@pagetitle = 'most recent %d emails sent' % [howmany]
		erb :emails
	end

	get '/formletters' do
		@formletters = @p.formletters
		@pagetitle = 'form letters'
		erb :formletters
	end

	post '/formletters' do
		res = @p.add_formletter(params[:title])
		if res
			redirect to('/formletter/%d' % res[:id])
		else
			redirect to('/formletters')
		end
	end

	get %r{^/person/([0-9]+)/formletter/([0-9]+).json$} do |person_id, formletter_id|
		@p.get_formletter_for_person(formletter_id, person_id).to_json
	end

	get %r{^/formletter/([0-9]+)$} do |id|
		@formletter = @p.get_formletter(id) || halt(404)
		@pagetitle = 'formletter %d' % id
		erb :formletter
	end

	post %r{^/formletter/([0-9]+)$} do |id|
		@p.update_formletter(id, params)
		redirect to('/formletter/%d' % id)
	end

	post %r{^/formletter/([0-9]+)/delete$} do |id|
		@p.delete_formletter(id)
		redirect to('/formletters')
	end

	get '/countries' do
		@countries = @p.country_count
		@pagetitle = 'countries'
		@cc = @p.country_names
		erb :where_countries
	end

	get %r{^/states/([A-Z][A-Z])$} do |country_code|
		@country = country_code
		@states = @p.state_count(country_code)
		@pagetitle = 'states for %s' % country_code
		erb :where_states
	end

	get %r{^/cities/([A-Z][A-Z])$} do |country_code|
		@country = country_code
		@cities = @p.city_count(country_code)
		@state = nil
		@pagetitle = 'cities for %s' % country_code
		erb :where_cities
	end

	get %r{^/cities/([A-Z][A-Z])/(\S+)$} do |country_code, state_name|
		@country = country_code
		@cities = @p.city_count(country_code, state_name)
		@state = state_name
		@pagetitle = 'cities for %s, %s' % [state_name, country_code]
		erb :where_cities
	end

	get %r{^/where/([A-Z][A-Z])} do |country_code|
		city = params[:city]
		state = params[:state]
		@people = @p.where(country_code, city, state)
		@pagetitle = 'People in %s' % [city, state, country_code].compact.join(', ')
		erb :people
	end

	get %r{^/stats/(\S+)/(\S+)$} do |statkey, statvalue| 
		@stats = @p.stats_with_key_value(statkey, statvalue)
		@statkey = statkey
		@valuecount = @p.statvalues_count(statkey)
		@pagetitle = '%s = %s' % [statkey, statvalue]
		erb :stats_people
	end

	get %r{^/stats/(\S+)$} do |statkey| 
		@stats = @p.stats_with_key(statkey)
		@statkey = statkey
		@valuecount = @p.statvalues_count(statkey)
		@pagetitle = statkey
		erb :stats_people
	end

	get '/stats' do
		@stats = @p.statkeys_count
		@pagetitle = 'stats'
		erb :stats_count
	end

	get '/merge' do
		@id1 = params[:id1].to_i
		@person1 = (@id1 == 0) ? nil : @p.get_person(@id1) 
		@id2 = params[:id2].to_i
		@person2 = (@id2 == 0) ? nil : @p.get_person(@id2) 
		@q = params[:q]
		@results = (@q) ? @p.person_search(@q) : false
		@pagetitle = 'merge'
		erb :merge
	end

	post %r{^/merge/([0-9]+)$} do |id|
		if @p.merge_into_person(id, params[:id2])
			redirect to('/person/%d' % id)
		else
			# TODO: flash error that not allowed?
			redirect to('/merge?id1=%d&id2=%d' % [id, params[:id2]])
		end
	end

end

