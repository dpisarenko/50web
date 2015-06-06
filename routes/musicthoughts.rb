require 'sinatra/base'

require 'r18n-core'
include R18n::Helpers
R18n.default_places = File.expand_path('../../i18n/musicthoughts/', __FILE__)

require 'b50d/musicthoughts'

class MusicThoughts < Sinatra::Base

	log = File.new('/tmp/MusicThoughts.log', 'a+')
	log.sync = true

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new { File.join(root, 'views/musicthoughts') }
	end

	helpers do
		def h(str)
			str.encode(str.encoding, :xml => :attr)[1...-1]
		end
	end

	# returns hash of langcode => url
	def page_in_other_languages(req, lang, langhash)
		others = {}
		tld = req.host.include?('dev') ? 'dev' : 'com'
		(langhash.keys - [lang]).each do |l|
			subdomain = (l == 'en') ? '' : "#{l}."
			others[l] = 'http://%smusicthoughts.%s%s' % [subdomain, tld, req.path]
		end
		others
	end

	# Returns first 10 words or first 20 characters of quote
	def snip_for_lang(str, language_code)
		if ['zh', 'ja'].include? language_code
			return (str[0,20] + '…')
		else
			return (str.split(' ')[0,10].join(' ') + '…')
		end
	end

	before do
		env['rack.errors'] = log
		@languages = {'en' => 'English',
			'es' => 'Español',
			'fr' => 'Français',
			'de' => 'Deutsch',
			'it' => 'Italiano',
			'pt' => 'Português',
			'ru' => 'Русский',
			'ar' => 'العربية',
			'ja' => '日本',
			'zh' => '中文'}
		# Nginx should only be routing these 2-letter language subdomains 
		# If found at beginning of URL, use as lang.  Otherwise 'en'.
		m = /^([a-z]{2})\./.match request.host
		@lang = m ? m[1] : 'en'
		R18n.set(@lang)
		@dir = (@lang == 'ar') ? 'rtl' : 'ltr'
		@rel_alternate = page_in_other_languages(request, @lang, @languages)
		@mt = B50D::MusicThoughts.new('live', @lang)
		@rand1 = @mt.thought_random
	end

	['/', '/home'].each do |r|
		get r do
			@pagetitle = t.musicthoughts + ' - ' + t.musicthoughts_slogan
			@bodyid = 'home'
			erb :home
		end
	end

	get %r{^/t/([0-9]+)} do |id|
		@thought = @mt.thought(id)
		redirect to('/') if @thought.nil?
		@pagetitle = (t.author_quote_quote % [@thought[:author][:name], snip_for_lang(@thought[:thought], @lang)])
		@bodyid = 't'
		@authorlink = '<a href="/author/%d">%s</a>' % [@thought[:author][:id], @thought[:author][:name]]
		if String(@thought[:source_url]).length > 0
			@authorlink += (' ' + t.from + ' ' + @thought[:source_url])
		end
		@contriblink = ('<a href="/contributor/%d">%s</a>' % [@thought[:contributor][:id], @thought[:contributor][:name]])
		erb :thought
	end

	get '/t' do
		redirect to('/t/%d' % @rand1[:id]), 307
	end

	get %r{^/cat/([0-9]+)} do |id|
		@category = @mt.category(id)
		redirect to('/') if @category.nil?
		@pagetitle = t.musicthoughts + ' - ' + @category[:category]
		@bodyid = 'cat'
		@thoughts = @category[:thoughts]
		erb :category
	end

	get '/cat' do
		redirect to('/')
	end

	get '/new' do
		@thoughts = @mt.thoughts_new
		@pagetitle = t.new + ' ' + t.musicthoughts
		@bodyid = 'new'
		erb :new
	end

	get %r{^/author/([0-9]+)} do |id|
		@author = @mt.author(id)
		redirect to('/author') if @author.nil?
		@thoughts = @author[:thoughts].shuffle
		@pagetitle = @author[:name] + ' ' + t.musicthoughts
		@bodyid = 'author'
		erb :author
	end

	get '/author' do
		@authors = @mt.authors_top
		@pagetitle = t.musicthoughts + ' ' + t.authors
		@bodyid = 'authors'
		erb :authors
	end

	get %r{^/contributor/([0-9]+)} do |id|
		@contributor = @mt.contributor(id)
		redirect to('/contributor') if @contributor.nil?
		@thoughts = @contributor[:thoughts].shuffle
		@pagetitle = @contributor[:name] + ' ' + t.musicthoughts
		@bodyid = 'contributor'
		erb :contributor
	end

	get '/contributor' do
		@contributors = @mt.contributors_top
		@pagetitle = t.musicthoughts + ' ' + t.contributors
		@bodyid = 'contributors'
		erb :contributors
	end

	get '/search' do
		@pagetitle = t.search + ' ' + t.musicthoughts
		@bodyid = 'search'
		@results = false
		if params[:q]
			@searchterm = params[:q].strip
			@pagetitle = @searchterm + ' ' + @pagetitle
			@results = @mt.search(@searchterm) # TODO
		end
		erb :search
	end

	get '/add' do
		@pagetitle = t.add_thought
		@bodyid = 'add'
		erb :add
	end

	post '/add' do
		if ['موسيقى', 'Musik', 'musik', 'music', 'música', 'musique', 'musica', '音楽', 'музыка'].include? params[:verify]
			@mt.add(params)
		end
		redirect to('/thanks')
	end

	get '/thanks' do
		@pagetitle = t.thank_you_big
		@bodyid = 'thanks'
		erb :thanks
	end
end

