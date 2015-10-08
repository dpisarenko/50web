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

end

