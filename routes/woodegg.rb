require 'sinatra/base'
require 'b50d/woodegg'
require 'kramdown'

class WoodEgg < Sinatra::Base

	helpers do
		def h(text)
			Rack::Utils.escape_html(text)
		end
	end

	configure do
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/woodegg') }
	end

	before do
		@we = B50D::WoodEgg.new
		unless '/login' == request.path_info
			unless @customer = @we.customer_from_cookie(request.cookies['ok'])
				redirect to('/login')
			end
		end
		@pagetitle = 'Wood Egg'
		@country_name= {'KH'=>'Cambodia','CN'=>'China','HK'=>'Hong Kong','IN'=>'India','ID'=>'Indonesia','JP'=>'Japan','KR'=>'Korea','MY'=>'Malaysia','MN'=>'Mongolia','MM'=>'Myanmar','PH'=>'Philippines','SG'=>'Singapore','LK'=>'Sri Lanka','TW'=>'Taiwan','TH'=>'Thailand','VN'=>'Vietnam'}
	end

	get '/login' do
		@pagetitle = 'log in'
		erb :login
	end

	post '/login' do
		redirect to('/login') unless params[:password] && (/\S+@\S+\.\S+/ === params[:email])
		if x = @we.login(params[:email], params[:password])
			response.set_cookie('ok', value: x[:cookie], path: '/', secure: true, httponly: true)
			redirect to('/home')
		else
			redirect to('/login')
		end
	end

	get '/logout' do
		response.set_cookie('ok', value: '', path: '/', expires: Time.at(0), secure: true, httponly: true)
		redirect to('/login')
	end

	get '/home' do
		@pagetitle = 'HOME'
		erb :home
	end

	get %r{^/country/(CN|HK|ID|IN|JP|KH|KR|LK|MM|MN|MY|PH|SG|TH|TW|VN)$} do |cc|
		@country = @we.country(cc)
		@uploads = @we.uploads(cc)
		@pagetitle = @country_name[cc]
		erb :country
	end

	get %r{\A/template/([0-9]+)\Z} do |id|
		@template = @we.template(id) || halt(404)
		@pagetitle = @template[:question]
		erb :template
	end

	get %r{\A/question/([0-9]+)\Z} do |id|
		@question = @we.question(id) || halt(404)
		@pagetitle = @question[:question]
		erb :question
	end

	get %r{\A/upload/([0-9]+)\Z} do |id|
		@upload = @we.upload(id) || halt(404)
		@pagetitle = @upload[:filename]
		erb :upload
	end

end

