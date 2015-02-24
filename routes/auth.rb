require 'sinatra/base'
require 'a50c/auth'

class AuthWeb < Sinatra::Base

	configure do
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/auth') }
	end

	before do
		@a = A50C::Auth.new
		@pagetitle = '50.io AUTH'
	end

	get '/' do
		erb :home
	end

	post '/login' do
		@my = @a.auth(params[:email], params[:password])
		if @my && @my.apis.size > 0
			erb :ok
		else
			erb :bad
		end
	end

end

