require 'sinatra/base'
require 'b50d/lat'

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
		livetest = (/dev$/ === request.env['SERVER_NAME']) ? 'test' : 'live'
		@l = B50D::Lat.new(livetest)
	end

	get '/' do
		@tags = @l.tags
		erb :home
	end

	get '/concepts' do
		@concepts = @l.get_concepts
		erb :concepts
	end

	get '/pairings' do
		@pairings = @l.get_pairings
		erb :pairings
	end

	post '/pairing' do
		if x = @l.create_pairing
			redirect to('/pairing/%d' % x[:id])
		else
			redirect to('/')
		end
	end

	get %r{\A/tagged/([a-z_-]+)\Z} do |tag|
		@concepts = @l.concepts_tagged(tag)
		erb :concepts
	end

	post '/concept' do
		if x = @l.create_concept(params[:title], params[:concept])
			redirect to('/concept/%d' % x[:id])
		else
			redirect to('/')
		end
	end

	get %r{\A/concept/([0-9]+)\Z} do |id|
		@concept = @l.get_concept(id)
		erb :concept
	end

	post %r{\A/concept/([0-9]+)\Z} do |id|
		@l.update_concept(id, params[:title], params[:concept])
		redirect to('/concept/%d' % id)
	end

	post %r{\A/concept/([0-9]+)/delete\Z} do |id|
		@l.delete_concept(id)
		redirect to('/')
	end

	post %r{\A/concept/([0-9]+)/url\Z} do |id|
		@l.add_url(id, params[:url], params[:notes])
		redirect to('/concept/%d' % id)
	end

	post %r{\A/concept/([0-9]+)/url/([0-9]+)\Z} do |id, url_id|
		@l.update_url(url_id, params[:url], params[:notes])
		redirect to('/concept/%d' % id)
	end

	post %r{\A/concept/([0-9]+)/url/([0-9]+)/delete\Z} do |id, url_id|
		@l.delete_url(url_id)
		redirect to('/concept/%d' % id)
	end

	post %r{\A/concept/([0-9]+)/tag\Z} do |id|
		@l.tag_concept(id, params[:tag])
		redirect to('/concept/%d' % id)
	end

	post %r{\A/concept/([0-9]+)/tag/([0-9]+)/delete\Z} do |id, tag_id|
		@l.untag_concept(id, tag_id)
		redirect to('/concept/%d' % id)
	end

	get %r{\A/pairing/([0-9]+)\Z} do |id|
		@pairing = @l.get_pairing(id)
		erb :pairing
	end

	post %r{\A/pairing/([0-9]+)\Z} do |id|
		@l.update_pairing(id, params[:thoughts])
		redirect to('/pairing/%d' % id)
	end

	post %r{\A/pairing/([0-9]+)/delete\Z} do |id|
		@l.delete_pairing(id)
		redirect to('/')
	end

	post %r{\A/pairing/([0-9]+)/tag\Z} do |id|
		@l.tag_pairing(id, params[:tag])
		redirect to('/pairing/%d' % id)
	end

end

