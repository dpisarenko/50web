require 'sinatra/base'
require 'getdb'

class Lat < Sinatra::Base

	log = File.new('/tmp/Lat.log', 'a+')
	log.sync = true

	helpers do
		def h(text)
			Rack::Utils.escape_html(text)
		end
	end

	configure do
		enable :logging
		set :root, File.dirname(File.dirname(File.realpath(__FILE__)))
		set :views, Proc.new {File.join(root, 'views/lat')}
	end

	before do
		env['rack.errors'] = log
		#livetest = (/dev$/ === request.env['SERVER_NAME']) ? 'test' : 'live'
		@db = getdb('lat')
	end

	get '/' do
		ok, @tags = @db.call('tags')
		erb :home
	end

	get '/concepts' do
		ok, @concepts = @db.call('get_concepts')
		erb :concepts
	end

	get '/pairings' do
		ok, @pairings = @db.call('get_pairings')
		erb :pairings
	end

	post '/pairing' do
		ok, x = @db.call('create_pairing')
		if ok
			redirect to('/pairing/%d' % x[:id])
		else
			redirect to('/')
		end
	end

	get %r{\A/tagged/([a-z_-]+)\Z} do |tag|
		ok, @concepts = @db.call('concepts_tagged', tag)
		erb :concepts
	end

	post '/concept' do
		ok, x = @db.call('create_concept', params[:title], params[:concept])
		if ok
			redirect to('/concept/%d' % x[:id])
		else
			redirect to('/')
		end
	end

	get %r{\A/concept/([0-9]+)\Z} do |id|
		ok, @concept = @db.call('get_concept', id)
		erb :concept
	end

	post %r{\A/concept/([0-9]+)\Z} do |id|
		@db.call('update_concept', id, params[:title], params[:concept])
		redirect to('/concept/%d' % id)
	end

	post %r{\A/concept/([0-9]+)/delete\Z} do |id|
		@db.call('delete_concept', id)
		redirect to('/')
	end

	post %r{\A/concept/([0-9]+)/url\Z} do |id|
		@db.call('add_url', id, params[:url], params[:notes])
		redirect to('/concept/%d' % id)
	end

	post %r{\A/concept/([0-9]+)/url/([0-9]+)\Z} do |id, url_id|
		@db.call('update_url', url_id, params[:url], params[:notes])
		redirect to('/concept/%d' % id)
	end

	post %r{\A/concept/([0-9]+)/url/([0-9]+)/delete\Z} do |id, url_id|
		@db.call('delete_url', url_id)
		redirect to('/concept/%d' % id)
	end

	post %r{\A/concept/([0-9]+)/tag\Z} do |id|
		@db.call('tag_concept', id, params[:tag])
		redirect to('/concept/%d' % id)
	end

	post %r{\A/concept/([0-9]+)/tag/([0-9]+)/delete\Z} do |id, tag_id|
		@db.call('untag_concept', id, tag_id)
		redirect to('/concept/%d' % id)
	end

	get %r{\A/pairing/([0-9]+)\Z} do |id|
		ok, @pairing = @db.call('get_pairing', id)
		erb :pairing
	end

	post %r{\A/pairing/([0-9]+)\Z} do |id|
		@db.call('update_pairing', id, params[:thoughts])
		redirect to('/pairing/%d' % id)
	end

	post %r{\A/pairing/([0-9]+)/delete\Z} do |id|
		@db.call('delete_pairing', id)
		redirect to('/')
	end

	post %r{\A/pairing/([0-9]+)/tag\Z} do |id|
		@db.call('tag_pairing', id, params[:tag])
		redirect to('/pairing/%d' % id)
	end

end

