require_relative 'mod_auth'

class MuckWorkerWeb < ModAuth

	log = File.new('/tmp/MuckWorkerWeb.log', 'a+')
	log.sync = true

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/muck-worker') }
	end

	helpers do
		def h(text)
			Rack::Utils.escape_html(text)
		end
	end

	before do
		@api = 'Muckworker'
		@livetest = 'test'
		env['rack.errors'] = log
		if String(request.cookies['api_key']).size == 8 && String(request.cookies['api_pass']).size == 8
			@db = getdb('muckwork', @livetest)
			ok, res = @db.call('auth_worker', request.cookies['api_key'], request.cookies['api_pass'])
			raise 'bad API auth' unless ok
			@worker_id = res[:worker_id]
			@person_id = res[:person_id]
			ok, @worker = @db.call('get_worker', @worker_id)
		end
	end

	get '/' do
		@pagetitle = 'Muckwork'
		@grouped_tasks = {}
		ok, res = @db.call('worker_get_tasks', @worker_id)
		res.each do |t|
			@grouped_tasks[t[:status]] ||= []
			@grouped_tasks[t[:status]] << t
		end
		# only show available tasks if they have no started/approved tasks
		@avaliable = nil
		if [] == (%w(started approved) & @grouped_tasks.keys)
			ok, @available = @db.call('next_available_tasks')
		end
		erb :home
	end

	get '/account' do
		db2 = getdb_noschema(@livetest)
		@pagetitle = @worker[:name] + ' ACCOUNT'
		ok, @locations = db2.call('peeps.all_countries')
		ok, @currencies = db2.call('core.all_currencies')
		erb :account
	end

	post '/account' do
		filtered = params.reject {|k,v| k == :person_id}
		@db.call('update_worker', @worker_id, filtered)
		redirect to('/account?msg=updated')
	end

	post '/password' do
		db2 = getdb_noschema(@livetest)
		db2.call('peeps.set_password', @person_id, params[:password])
		redirect to('/account?msg=newpass')
	end

	post %r{\A/claim/([0-9]+)\Z} do |task_id|
		ok, res = @db.call('claim_task', task_id, @worker_id)
		if ok
			redirect to("/task/#{task_id}")
		else
			redirect to('/?msg=claimfail')
		end
	end

	get %r{\A/task/([0-9]+)\Z} do |task_id|
		ok, res = @db.call('worker_owns_task', @worker_id, task_id)
		halt(400) unless res == {ok: true}
		ok, @task = @db.call('get_task', task_id)
		halt(404) unless ok
		@pagetitle = "TASK %d : %s" % [task_id, @task[:title]]
		erb :task
	end

	post %r{\A/unclaim/([0-9]+)\Z} do |task_id|
		ok, res = @db.call('worker_owns_task', @worker_id, task_id)
		halt(400) unless res == {ok: true}
		ok, res = @db.call('unclaim_task', task_id)
		if ok
			redirect to('/')
		else
			redirect to("/task/#{task_id}?msg=unclaimfail")
		end
	end

	post %r{\A/start/([0-9]+)\Z} do |task_id|
		ok, res = @db.call('worker_owns_task', @worker_id, task_id)
		halt(400) unless res == {ok: true}
		ok, res = @db.call('start_task', task_id)
		if ok
			redirect to("/task/#{task_id}")
		else
			redirect to("/task/#{task_id}?msg=startfail")
		end
	end

	post %r{\A/finish/([0-9]+)\Z} do |task_id|
		ok, res = @db.call('worker_owns_task', @worker_id, task_id)
		halt(400) unless res == {ok: true}
		ok, res = @db.call('finish_task', task_id)
		if ok
			redirect to('/')
		else
			redirect to("/task/#{task_id}?msg=finishfail")
		end
	end
end

