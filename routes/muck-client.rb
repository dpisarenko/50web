require_relative 'mod_auth'

require 'b50d/muckwork'

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
			@mc = B50D::MuckworkClient.new(request.cookies['api_key'], request.cookies['api_pass'], @livetest)
			@client = @mc.get_client
		end
	end

	get '/' do
		@projects = @mc.get_projects
		@pagetitle = @client[:name] + ' HOME'
		erb :home
	end

	get '/account' do
		@pagetitle = @client[:name] + ' ACCOUNT'
		erb :account
	end

	post '/account' do
		@mc.update(params[:currency])
		redirect to('/account')
	end

	post '/projects' do
		p = @mc.create_project(params[:title], params[:description])
		if p
			redirect to('/project/%d' % p[:id])
		else
			redirect to('/')
		end
	end

	get %r{\A/project/([0-9]+)\Z} do |id|
		@project = @mc.get_project(id) || halt(404)
		@pagetitle = @project[:title]
		erb :project
	end

	get %r{\A/project/([0-9]+)/task/([0-9]+)\Z} do |project_id, task_id|
		@task = @mc.get_project_task(project_id, task_id) || halt(404)
		@pagetitle = @task[:title]
		erb :task
	end

	post %r{\A/project/([0-9]+)\Z} do |id|
		@mc.update_project(id, params[:title], params[:description])
		redirect to('/project/%d' % id)
	end

	post %r{\A/project/([0-9]+)/approve\Z} do |id|
		@mc.approve_quote(id)
		redirect to('/project/%d' % id)
	end

	post %r{\A/project/([0-9]+)/refuse\Z} do |id|
		@mc.refuse_quote(id, params[:reason])
		redirect to('/project/%d' % id)
	end

end

