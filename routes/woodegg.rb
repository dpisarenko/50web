require 'sinatra/base'
require 'b50d/woodegg'
require 'kramdown'

class WoodEgg < Sinatra::Base

	log = File.new('/tmp/WoodEgg.log', 'a+')
	log.sync = true

	helpers do
		def h(text)
			Rack::Utils.escape_html(text)
		end
	end

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/woodegg') }
	end

	before do
		env['rack.errors'] = log
		@we = B50D::WoodEgg.new
		unless ['/login', '/register'].include? request.path_info
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

	post '/register' do
		unless params[:password] && (/\S+@\S+\.\S+/ === params[:email]) && String(params[:name]).size > 1 && String(params[:proof]).size > 10
			redirect to('/login')
		end
		unless @person = @we.register(params)
			redirect to('/login')
		end
		@pagetitle = 'thank you'
		erb :register
	end

	post '/login' do
		redirect to('/login') unless params[:password] && (/\S+@\S+\.\S+/ === params[:email])
		if x = @we.login(params[:email], params[:password])
			response.set_cookie('ok', value:x[:cookie], path:'/', secure:true, httponly:true)
			redirect to('/home')
		else
			redirect to('/login')
		end
	end

	get '/logout' do
		response.set_cookie('ok', value:'', path:'/', expires:Time.at(0), secure:true, httponly:true)
		redirect to('/login')
	end

	get '/' do
		@pagetitle = 'HOME'
		erb :home
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
		@upload[:filename].gsub!(/^r[0-9]{3}/, 'WoodEgg')
		@pagetitle = @upload[:filename]
		erb :upload
	end

	get  %r{/download/([A-Z][a-zA-Z]+2014\.[a-z]+)\Z} do |filename|
		files = %w(Asia2014.epub Asia2014.mobi Asia2014.pdf Cambodia2014.epub Cambodia2014.mobi Cambodia2014.pdf China2014.epub China2014.mobi China2014.pdf HongKong2014.epub HongKong2014.mobi HongKong2014.pdf India2014.epub India2014.mobi India2014.pdf Indonesia2014.epub Indonesia2014.mobi Indonesia2014.pdf Japan2014.epub Japan2014.mobi Japan2014.pdf Korea2014.epub Korea2014.mobi Korea2014.pdf Malaysia2014.epub Malaysia2014.mobi Malaysia2014.pdf Mongolia2014.epub Mongolia2014.mobi Mongolia2014.pdf Myanmar2014.epub Myanmar2014.mobi Myanmar2014.pdf Philippines2014.epub Philippines2014.mobi Philippines2014.pdf Singapore2014.epub Singapore2014.mobi Singapore2014.pdf SriLanka2014.epub SriLanka2014.mobi SriLanka2014.pdf Taiwan2014.epub Taiwan2014.mobi Taiwan2014.pdf Thailand2014.epub Thailand2014.mobi Thailand2014.pdf Vietnam2014.epub Vietnam2014.mobi Vietnam2014.pdf)
		halt(404) unless files.include? filename
		send_file "/var/www/htdocs/downloads/#{filename}"
	end

	get %r{\A/download/([0-9]+)/WoodEgg.*\Z} do |id|
		up = @we.upload(id) || halt(404)
		send_file "/var/www/htdocs/uploads/#{up[:filename]}",
			filename: up[:filename].gsub(/^r[0-9]{3}/, 'WoodEgg')
	end

end

