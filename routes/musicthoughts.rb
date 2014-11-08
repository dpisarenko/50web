require 'sinatra/base'

require 'langur'
LANGUAGES = %w(ar de en es fr it ja pt ru zh)
LangCode.only(LANGUAGES)

require 'r18n-core'
include R18n::Helpers
R18n.default_places = File.expand_path('../../i18n/musicthoughts/', __FILE__)

require 'a50c/musicthoughts'

class MusicThoughtsWeb < Sinatra::Base
  use Langur

  configure do
    set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
    set :views, Proc.new { File.join(root, 'views/musicthoughts') }
  end

  # returns hash of langcode => url
  def page_in_other_languages(env, lang)
    others = {}
    (LANGUAGES - [lang]).each do |l|
      pathinfo = (env['PATH_INFO'] == '/') ? '/home' : env['PATH_INFO']
      others[l] = 'http://' + env['HTTP_HOST'] + pathinfo + '/' + l  # TODO: SSL?
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
    @lang = @env['lang']
    @dir = (@lang == 'ar') ? 'rtl' : 'ltr'
    R18n.set(@env['lang'])
    @rel_alternate = page_in_other_languages(@env, @lang)
    @mt = A50C::MusicThoughts.new('http://127.0.0.1:9000', @lang)
    @rand1 = @mt.thought_random
    #@categories = @mt.categories
  end

  ['/', '/home'].each do |r|
    get r do
      @pagetitle = t.musicthoughts + ' - ' + t.musicthoughts_slogan
      @bodyid = 'home'
      erb :home
    end
  end

  get '/t/:id' do
    @thought = @mt.thought(params[:id])
    redirect '/' if @thought.nil?
    @pagetitle = (t.author_quote_quote % [@thought.author.name, snip_for_lang(@thought.thought, @lang)])
    @bodyid = 't'
    @authorlink = '<a href="/author/%d">%s</a>' % [@thought.author.id, @thought.author.name]
    if @thought.source_url.to_s.length > 0
      @authorlink += (' ' + t.from + ' ' + @thought.source_url)
    end
    @contriblink = ('<a href="/contributor/%d">%s</a>' % [@thought.contributor.id, @thought.contributor.name])
    erb :thought
  end

  get '/t' do
    redirect('/t/%d' % @rand1.id, 307)
  end

  get %r{^/cat/([0-9]+)} do |id|
    @category = @mt.category(id)
    redirect '/' if @category.nil?
    @pagetitle = t.musicthoughts + ' - ' + @category.name
    @bodyid = 'cat'
    @thoughts = @category.thoughts.shuffle
    erb :category
  end

  get '/cat' do
    redirect '/'
  end

  get '/new' do
    @thoughts = @mt.thoughts_new
    @pagetitle = t.new + ' ' + t.musicthoughts
    @bodyid = 'new'
    erb :new
  end

  get %r{^/author/([0-9]+)} do |id|
    @author = @mt.author(id)
    redirect '/author' if @author.nil?
    @thoughts = @author.thoughts.shuffle
    @pagetitle = @author.name + ' ' + t.musicthoughts
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
    redirect '/contributor' if @contributor.nil?
    @thoughts = @contributor.thoughts.shuffle
    @pagetitle = @contributor.name + ' ' + t.musicthoughts
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
      @results = @mt.search(@searchterm)
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
    redirect '/thanks'
  end

  get '/thanks' do
    @pagetitle = t.thank_you_big
    @bodyid = 'thanks'
    erb :thanks
  end
end

