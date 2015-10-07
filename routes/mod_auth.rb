require 'sinatra/base'
require 'b50d/peeps'

class ModAuth < Sinatra::Base

	helpers do
		def protected!
			redirect to('/login') unless has_cookie?
		end

		def has_cookie?
			request.cookies['person_id'] && request.cookies['api_key'] && request.cookies['api_pass']
		end
	end

	# set @api and @livetest in child controller's before block
	before do
		protected! unless '/login' == request.path_info
	end

	get '/login' do
		@pagetitle = 'log in'
		erb :login
	end

	post '/login' do
		redirect to('/login?err=missing') unless params[:password] && (/\S+@\S+\.\S+/ === params[:email])
		if res = B50D::Peeps.auth(@livetest, params[:email], params[:password], @api)
			response.set_cookie('person_id', value: res[:person_id], path: '/', secure: true, httponly: true)
			response.set_cookie('api_key', value: res[:akey], path: '/', secure: true, httponly: true)
			response.set_cookie('api_pass', value: res[:apass], path: '/', secure: true, httponly: true)
			redirect to('/')
		else
			redirect to('/login?err=wrong')
		end
	end

	get '/logout' do
		response.set_cookie('person_id', value: '', path: '/', expires: Time.at(0), secure: true, httponly: true)
		response.set_cookie('api_key', value: '', path: '/', expires: Time.at(0), secure: true, httponly: true)
		response.set_cookie('api_pass', value: '', path: '/', expires: Time.at(0), secure: true, httponly: true)
		redirect to('/login')
	end

end
