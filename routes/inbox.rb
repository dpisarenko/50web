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

		def redirect_to_email_or_home(ok, email)
			if ok
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
			@db = getdb('peeps', @livetest)
			ok, res = @db.call('auth_emailer', request.cookies['api_key'], request.cookies['api_pass'])
			raise 'bad API auth' unless ok
			@eid = res[:id]
			# TODO: erase this next line once no more @p calls, below
			# @p = B50D::Peeps.new(request.cookies['api_key'], request.cookies['api_pass'], @livetest)
		end
	end

	get '/' do
		@unopened_email_count = @db.call('unopened_email_count', @eid)[1]
		@open_emails = @db.call('opened_emails', @eid)[1]
		@unknowns_count = @db.call('count_unknowns', @eid)[1][:count]
		@pagetitle = 'inbox'
		erb :home
	end

	get '/unknown' do
		ok, @unknown = @db.call('get_next_unknown', @eid)
		redirect to('/') unless ok
		@search = (params[:search]) ? params[:search].strip : nil
		if @search
			ok, @results = @db.call('people_search', @search)
		end
		@pagetitle = 'unknown'
		erb :unknown
	end
 
	post %r{^/unknown/([0-9]+)$} do |email_id|
		person_id = (params[:person_id]) ? params[:person_id].to_i : 0
		@db.call('set_unknown_person', @eid, email_id, person_id)
		redirect to('/unknown')
	end

	post %r{^/unknown/([0-9]+)/delete$} do |email_id|
		@db.call('delete_unknown', @eid, email_id)
		redirect to('/unknown')
	end

	get '/unopened' do
		ok, @emails = @db.call('unopened_emails', @eid, params[:profile], params[:category])
		@pagetitle = 'unopened for %s: %s' % [params[:profile], params[:category]]
		erb :emails
	end

	get '/unemailed' do
		ok, @people = @db.call('people_unemailed')
		@pagetitle = 'unemailed'
		erb :people
	end

	post '/next_unopened' do
		ok, email = @db.call('open_next_email', @eid, params[:profile], params[:category])
		redirect_to_email_or_home(ok, email)
	end

	get %r{^/email/([0-9]+)$} do |id|
		ok, @email = @db.call('get_email', @eid, id)
		halt 404 unless ok
		@person = @email[:person]
		@clash = (@email[:their_email] != @person[:email])
		@profiles = ['derek@sivers', 'we@woodegg']
		# skip formletters that start with _, since those are automated
		ok, res = @db.call('get_formletters')
		@formletters = res.reject {|x| x[:title][0] == '_'}
		ok, @locations = @db.call('all_countries')
		@pagetitle = 'email %d from %s' % [id, @person[:name]]
		erb :email
	end

	post %r{^/email/([0-9]+)$} do |id|
		@db.call('update_email', @eid, id, params.to_json)
		redirect to('/email/%d' % id)
	end

	post %r{^/email/([0-9]+)/delete$} do |id|
		@db.call('delete_email', @eid, id)
		redirect '/'
	end

	post %r{^/email/([0-9]+)/unread$} do |id|
		@db.call('unread_email', @eid, id)
		redirect '/'
	end

	post %r{^/email/([0-9]+)/close$} do |id|
		@db.call('close_email', @eid, id)
		ok, email = @db.call('open_next_email', @eid, params[:profile], params[:category])
		redirect_to_email_or_home(ok, email)
	end

	post %r{^/email/([0-9]+)/reply$} do |id|
		@db.call('reply_to_email', @eid, id, params[:reply])
		ok, email = @db.call('open_next_email', @eid, params[:profile], params[:category])
		redirect_to_email_or_home(ok, email)
	end

	post %r{^/email/([0-9]+)/not_my$} do |id|
		@db.call('not_my_email', @eid, id)
		redirect '/'
	end

	post '/person' do
		ok, person = @db.call('new_person', params[:name], params[:email])
		redirect to('/person/%d' % person[:id])
	end

	get %r{^/person/([0-9]+)$} do |id|
		ok, @person = @db.call('get_person', id)
		halt(404) unless ok
		@emails = @db.call('get_person_emails', id)[1].reverse
		@tables = @db.call('tables_with_person', id)[1].sort
		@tables.map! do |t|
			(t == 'sivers.comments') ?
				('<a href="' + (SCP % id) + '">sivers.comments</a>') : t
		end
		@profiles = ['derek@sivers', 'we@woodegg']
		ok, @locations = @db.call('all_countries')
		@pagetitle = 'person %d = %s' % [id, @person[:name]]
		erb :personfull
	end

	post %r{^/person/([0-9]+)$} do |id|
		@db.call('update_person', id, params.to_json)
		redirect_to_email_or_person(params[:email_id], id)
	end

	post %r{^/person/([0-9]+)/annihilate$} do |id|
		@db.call('annihilate_person', id)
		redirect '/'
	end

	post %r{^/person/([0-9]+)/url.json$} do |id|
		ok, res = @db.call('add_url', id, params[:url])
		res.to_json
	end

	post %r{^/person/([0-9]+)/stat.json$} do |id|
		ok, res = @db.call('add_stat', id, params[:key], params[:value])
		res.to_json
	end

	post %r{^/person/([0-9]+)/email$} do |id|
		@db.call('new_email', id, params[:body], params[:subject], params[:profile])
		redirect to('/person/%d' % id)
	end

	post %r{^/person/([0-9]+)/match/([0-9]+)$} do |person_id, email_id|
		ok, res = @db.call('get_email', @eid, email_id)
		@db.call('update_person', person_id, {email: e[:their_email]}.to_json)
		redirect to('/email/%d' % email_id)
	end

	post %r{^/url/([0-9]+)/delete.json$} do |id|
		ok, res = @db.call('delete_url', id)
		res.to_json
	end

	post %r{^/stat/([0-9]+)/delete.json$} do |id|
		ok, res = @db.call('delete_stat', id)
		res.to_json
	end

	post %r{^/url/([0-9]+).json$} do |id|
		@db.call('update_url', id, {main: params[:star]}.to_json)
	end

	# to avoid external sites seeing my internal links:
	# <a href="/link?url=http://someothersite.com">someothersite.com</a>
	get '/link' do
		redirect to(params[:url])
	end

	get '/search' do
		@q = (params[:q]) ? params[:q] : false
		if @q
			ok, @results = @db.call('person_search', @q)
		end
		@pagetitle = 'search'
		erb :search
	end

	get '/sent' do
		ok, @grouped = @db.call('sent_emails_grouped')
		@pagetitle = 'sent emails'
		erb :sent
	end

	get '/formletters' do
		ok, @formletters = @db.call('get_formletters')
		@pagetitle = 'form letters'
		erb :formletters
	end

	post '/formletters' do
		ok, res = @db.call('create_formletter', params[:title])
		if ok
			redirect to('/formletter/%d' % res[:id])
		else
			redirect to('/formletters')
		end
	end

	get %r{^/person/([0-9]+)/formletter/([0-9]+).json$} do |person_id, formletter_id|
		ok, res = @db.call('parsed_formletter', person_id, formletter_id)
		res.to_json
	end

	get %r{^/formletter/([0-9]+)$} do |id|
		ok, @formletter = @db.call('get_formletter', id)
		halt(404) unless ok
		@pagetitle = 'formletter %d' % id
		erb :formletter
	end

	post %r{^/formletter/([0-9]+)$} do |id|
		@db.call('update_formletter', id, params.to_json)
		redirect to('/formletter/%d' % id)
	end

	post %r{^/formletter/([0-9]+)/delete$} do |id|
		@db.call('delete_formletter', id)
		redirect to('/formletters')
	end

	get '/countries' do
		ok, @countries = @db.call('country_count')
		@pagetitle = 'countries'
		ok, @cc = @db.call('country_names')
		erb :where_countries
	end

	get %r{^/states/([A-Z][A-Z])$} do |country_code|
		@country = country_code
		ok, @states = @db.call('state_count', country_code)
		@pagetitle = 'states for %s' % country_code
		erb :where_states
	end

	get %r{^/cities/([A-Z][A-Z])$} do |country_code|
		@country = country_code
		ok, @cities = @db.call('city_count', country_code)
		@state = nil
		@pagetitle = 'cities for %s' % country_code
		erb :where_cities
	end

	get %r{^/cities/([A-Z][A-Z])/(\S+)$} do |country_code, state_name|
		@country = country_code
		ok, @cities = @db.call('city_count', country_code, state_name)
		@state = state_name
		@pagetitle = 'cities for %s, %s' % [state_name, country_code]
		erb :where_cities
	end

	get %r{^/where/([A-Z][A-Z])} do |country|
		city = params[:city]
		state = params[:state]
		if state && city
			ok, @people = @db.call('people_from_state_city', country, state, city)
		elsif state
			ok, @people = @db.call('people_from_state', country, state)
		elsif city
			ok, @people = @db.call('people_from_city', country, city)
		else
			ok, @people = @db.call('people_from_country', country)
		end
		@pagetitle = 'People in %s' % [city, state, country].compact.join(', ')
		erb :people
	end

	get %r{^/stats/(\S+)/(\S+)$} do |statkey, statvalue| 
		ok, @stats = @db.call('get_stats', statkey, statvalue)
		@statkey = statkey
		ok, @valuecount = @db.call('get_stat_value_count', statkey)
		@pagetitle = '%s = %s' % [statkey, statvalue]
		erb :stats_people
	end

	get %r{^/stats/(\S+)$} do |statkey| 
		ok, @stats = @db.call('get_stats', statkey)
		@statkey = statkey
		ok, @valuecount = @db.call('get_stat_value_count', statkey)
		@pagetitle = statkey
		erb :stats_people
	end

	get '/stats' do
		ok, @stats = @db.call('get_stat_name_count')
		@pagetitle = 'stats'
		erb :stats_count
	end

	get '/merge' do
		@id1 = params[:id1].to_i
		@person1 = (@id1 == 0) ? nil : @db.call('get_person', @id1)[1]
		@id2 = params[:id2].to_i
		@person2 = (@id2 == 0) ? nil : @db.call('get_person', @id2)[1]
		@q = params[:q]
		@results = (@q) ? @db.call('people_search', @q.strip)[1] : false
		@pagetitle = 'merge'
		erb :merge
	end

	post %r{^/merge/([0-9]+)$} do |id|
		ok, res = @db.call('merge_person', id, params[:id2])
		if ok
			redirect to('/person/%d' % id)
		else
			# TODO: flash error that not allowed?
			redirect to('/merge?id1=%d&id2=%d' % [id, params[:id2]])
		end
	end

end

