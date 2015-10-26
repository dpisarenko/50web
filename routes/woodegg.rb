require 'sinatra/base'
require 'kramdown'
require 'b50d/getdb'

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
		@db = getdb('woodegg')
		unless ['/login', '/register'].include? request.path_info
			ok = false
			if /[a-zA-Z0-9]{32}:[a-zA-Z0-9]{32}/ === request.cookies['ok']
				ok, @customer = @db.call('get_customer', request.cookies['ok'])
			end
			redirect to('/login') unless ok
		end
		@pagetitle = 'Wood Egg'
		@country_name= {'KH'=>'Cambodia','CN'=>'China','HK'=>'Hong Kong','IN'=>'India','ID'=>'Indonesia','JP'=>'Japan','KR'=>'Korea','MY'=>'Malaysia','MN'=>'Mongolia','MM'=>'Myanmar','PH'=>'Philippines','SG'=>'Singapore','LK'=>'Sri Lanka','TW'=>'Taiwan','TH'=>'Thailand','VN'=>'Vietnam'}
	end

	get '/login' do
		@pagetitle = 'log in'
		erb :login
	end

	post '/register' do
		unless params[:password] && (/\A\S+@\S+\.\S+\Z/ === params[:email]) && \
			String(params[:name]).size > 1 && String(params[:proof]).size > 8
			redirect to('/login')
		end
		ok, @person = @db.call('register',
			params[:name], params[:email], params[:password], params[:proof])
		redirect to('/login') unless ok
		@pagetitle = 'thank you'
		erb :register
	end

	post '/login' do
		redirect to('/login') unless params[:password] && (/\S+@\S+\.\S+/ === params[:email])
		ok, res = @db.call('login', params[:email], params[:password])
		if ok
			response.set_cookie('ok', value: res[:cookie], path:'/', secure:true, httponly:true)
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
		ok, @country = @db.call('get_country', cc)
		ok, @uploads = @db.call('get_uploads', cc)
		@pagetitle = @country_name[cc]
		erb :country
	end

	get %r{\A/template/([0-9]+)\Z} do |id|
		ok, @template = @db.call('get_template', id)
		halt(404) unless ok
		@pagetitle = @template[:question]
		erb :template
	end

	get %r{\A/question/([0-9]+)\Z} do |id|
		ok, @question = @db.call('get_question', id)
		halt(404) unless ok
		@pagetitle = @question[:question]
		erb :question
	end

	get %r{\A/upload/([0-9]+)\Z} do |id|
		ok, @upload = @db.call('get_upload', id)
		halt(404) unless ok
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
		ok, up = @db.call('get_upload', id)
		halt(404) unless ok
		send_file "/var/www/htdocs/uploads/#{up[:filename]}",
			filename: up[:filename].gsub(/^r[0-9]{3}/, 'WoodEgg')
	end

end

