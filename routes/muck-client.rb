require_relative 'mod_auth'
require 'b50d/getdb'

class MuckClientWeb < ModAuth

	log = File.new('/tmp/MuckClientWeb.log', 'a+')
	log.sync = true

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/muck-client') }
	end

	helpers do
		def h(text)
			Rack::Utils.escape_html(text)
		end
	end

	before do
		@api = 'MuckworkClient'
		@livetest = 'test'
		env['rack.errors'] = log
		if String(request.cookies['api_key']).size == 8 && String(request.cookies['api_pass']).size == 8
			@db = getdb('muckwork', @livetest)
			ok, res = @db.call('auth_client', request.cookies['api_key'], request.cookies['api_pass'])
			raise 'bad API auth' unless ok
			@client_id = res[:client_id]
			@person_id = res[:person_id]
			ok, @client = @db.call('get_client', @client_id)
		end
	end

	get '/' do
		ok, @projects = @db.call('client_get_projects', @client_id)
		@pagetitle = @client[:name] + ' HOME'
		erb :home
	end

	get '/account' do
		db2 = getdb_noschema(@livetest)
		@pagetitle = @client[:name] + ' ACCOUNT'
		ok, @locations = db2.call('peeps.all_countries')
		ok, @currencies = db2.call('core.all_currencies')
		erb :account
	end

	post '/account' do
		filtered = params.reject {|k,v| k == :person_id}
		@db.call('update_client', @client_id, filtered)
		redirect to('/account?msg=updated')
	end

	post '/password' do
		db2 = getdb_noschema(@livetest)
		db2.call('peeps.set_password', @person_id, params[:password])
		redirect to('/account?msg=newpass')
	end

	post '/projects' do
		ok, p = @db.('create_project', @client_id, params[:title], params[:description])
		if ok
			redirect to('/project/%d' % p[:id])
		else
			redirect to('/')
		end
	end

	get %r{\A/project/([0-9]+)\Z} do |id|
		ok, res = @db.call('client_owns_project', @client_id, id)
		halt(400) unless res == {ok: true}
		ok, @project = @db.call('get_project', id)
		halt(404) unless ok
		@pagetitle = @project[:title]
		erb :project
	end

	get %r{\A/project/([0-9]+)/task/([0-9]+)\Z} do |project_id, task_id|
		ok, res = @db.call('client_owns_project', @client_id, project_id)
		halt(400) unless res == {ok: true}
		ok, @task = @db.call('get_project_task', project_id, task_id)
		halt(404) unless ok
		@pagetitle = @task[:title]
		erb :task
	end

	post %r{\A/project/([0-9]+)\Z} do |id|
		ok, res = @db.call('client_owns_project', @client_id, id)
		halt(400) unless res == {ok: true}
		ok, res = @db.call('update_project', id, params[:title], params[:description])
		redirect to('/project/%d' % id)
	end

	post %r{\A/project/([0-9]+)/approve\Z} do |id|
		ok, res = @db.call('client_owns_project', @client_id, id)
		halt(400) unless res == {ok: true}
		@db.call('approve_quote', id)
		redirect to('/project/%d' % id)
	end

	post %r{\A/project/([0-9]+)/refuse\Z} do |id|
		ok, res = @db.call('client_owns_project', @client_id, id)
		halt(400) unless res == {ok: true}
		@db.call('refuse_quote', id, params[:reason])
		redirect to('/project/%d' % id)
	end

end

