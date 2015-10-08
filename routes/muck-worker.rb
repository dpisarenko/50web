require_relative 'mod_auth'

require 'b50d/muckwork'

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
			@mr = B50D::Muckworker.new(request.cookies['api_key'], request.cookies['api_pass'], @livetest)
			@worker = @mr.get_worker
		end
	end

	get '/' do
		@pagetitle = 'Muckwork'
		@grouped_tasks = @mr.grouped_tasks
		# only show available tasks if they have no started/approved tasks
		@avaliable = nil
		if [] == (%w(started approved) & @grouped_tasks.keys)
			@available = @mr.next_available_tasks
		end
		erb :home
	end

	get '/account' do
		@pagetitle = @worker[:name] + ' ACCOUNT'
		@locations = @mr.locations
		@currencies = @mr.currencies
		erb :account
	end

	post '/account' do
		@mr.update(params)
		redirect to('/account?msg=updated')
	end

	post '/password' do
		@mr.set_password(params[:password])
		redirect to('/account?msg=newpass')
	end

	post %r{\A/claim/([0-9]+)\Z} do |task_id|
		if @mr.claim_task(task_id)
			redirect to("/task/#{task_id}")
		else
			redirect to('/?msg=claimfail')
		end
	end

	get %r{\A/task/([0-9]+)\Z} do |task_id|
		@task = @mr.get_task(task_id) || halt(404)
		@pagetitle = "TASK %d : %s" % [task_id, @task[:title]]
		erb :task
	end

	post %r{\A/unclaim/([0-9]+)\Z} do |task_id|
		if @mr.unclaim_task(task_id)
			redirect to('/')
		else
			redirect to("/task/#{task_id}?msg=unclaimfail")
		end
	end

	post %r{\A/start/([0-9]+)\Z} do |task_id|
		if @mr.start_task(task_id)
			redirect to("/task/#{task_id}")
		else
			redirect to("/task/#{task_id}?msg=startfail")
		end
	end

	post %r{\A/finish/([0-9]+)\Z} do |task_id|
		if @mr.finish_task(task_id)
			redirect to('/')
		else
			redirect to("/task/#{task_id}?msg=finishfail")
		end
	end
end

