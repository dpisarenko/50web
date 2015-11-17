require_relative 'mod_auth'

class SiversData < ModAuth

	log = File.new('/tmp/SiversData.log', 'a+')
	log.sync = true

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/sivers.data') }
	end

	before do
		env['rack.errors'] = log
		@db = getdb('peeps')
		@api = 'Data'
		@livetest = 'live'
	end

	helpers do
		def h(text)
			Rack::Utils.escape_html(text)
		end
	end

	get '/' do
		@pagetitle = 'your data'
		erb :home
	end

	get %r{\A/newpass/([0-9]+)/([0-9a-zA-Z]{8})\Z} do |id, newpass|
		ok, @person = @db.call('get_person_newpass', id, newpass)
		if ok
			@pagetitle = 'make a password'
			erb :newpass_good
		else
			@pagetitle = 'expired link'
			erb :newpass_bad
		end
	end

	post '/newpass' do
		redirect to('/login?err=missing') unless (params[:id] && params[:newpass])
		id = params[:id]
		newpass = params[:newpass]
		ok, _ = @db.call('get_person_newpass', id, newpass)
		redirect to('/login?err=badid') unless ok
		unless params[:setpass].length > 3
			redirect to('/newpass/%d/%s' % [id, newpass])
		end
		ok, _ = @db.call('set_password', id, params[:setpass])
		redirect to('/login?err=bad_set_pass') unless ok
		ok, res = @db.call('add_api', id, 'Sivers')
		redirect to('/login?err=wrong') unless ok
		response.set_cookie('person_id', value: id, path: '/', secure: true, httponly: true)
		response.set_cookie('api_key', value: res[:akey], path: '/', secure: true, httponly: true)
		response.set_cookie('api_pass', value: res[:apass], path: '/', secure: true, httponly: true)
		redirect to('/')
	end

	post '/email' do
		params[:email]
		# exists in db?
	end

end
