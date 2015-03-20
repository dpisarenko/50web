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
		set :views, Proc.new { File.join(root, 'views/lat') }
	end

	before do
		env['rack.errors'] = log
		@l = B50D::Lat.new('test')
	end

	get '/' do
		@tags = @l.tags
		erb :home
	end

	get %r{/tagged/([a-z_-]+)$} do |tag|
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

	get %r{/concept/([0-9]+)} do |id|
		@concept = @l.get_concept(id)
		erb :concept
	end

	post %r{/concept/([0-9]+)} do |id|
		@l.update_concept(id, params[:title], params[:concept])
		redirect to('/concept/%d' % id)
	end

	post %r{/concept/([0-9]+)/url/([0-9]+)/delete} do |id, url_id|
		@l.delete_url(url_id)
		redirect to('/concept/%d' % id)
	end

	post %r{/concept/([0-9]+)/url/([0-9]+)} do |id, url_id|
		@l.update_url(url_id, params[:url], params[:notes])
		redirect to('/concept/%d' % id)
	end

	post %r{/concept/([0-9]+)/url} do |id|
		@l.add_url(id, params[:url], params[:notes])
		redirect to('/concept/%d' % id)
	end

	post %r{/concept/([0-9]+)/tag} do |id|
		@l.tag_concept(id, params[:tag])
		redirect to('/concept/%d' % id)
	end

	post %r{/concept/([0-9]+)/tag/delete} do |id|
		@l.untag_concept(id, params[:tag_id])
		redirect to('/concept/%d' % id)
	end

	post %r{/concept/([0-9]+)/delete} do |id|
		@l.delete_concept(id)
		redirect to('/')
	end

	post '/pairing' do
		if x = @l.create_pairing
			redirect to('/pairing/%d' % x[:id])
		else
			redirect to('/')
		end
	end

	get %r{/pairing/([0-9]+)} do |id|
		@pairing = @l.get_pairing(id)
		erb :pairing
	end

	post %r{/pairing/([0-9]+)} do |id|
		@l.update_pairing(id, params[:thoughts])
		redirect to('/pairing/%d' % id)
	end

end

