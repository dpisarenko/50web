# checked for spam traits of posted form - (entire Rack request). Refuse or add to database.
require 'resolv'
require 'net/http'

# Treat all methods here as private, except the "PUBLIC" ones up top.
module FormFilter
	class << self

		# PUBLIC: Returns false if bad, hash of comment if done
		# PARAMS: Rack request of posted form, db_api = B50D::SiversComments.new
		def comment(env, db_api)
			fieldnames = %w(name email comment)
			refer_reg = %r{\Ahttps?://sivers\.(dev|org)/([a-z0-9_-]{1,32})\Z}
			return false unless m = refer_reg.match(env['HTTP_REFERER'])
			uri = m[2]
			return false unless has_these_fields?(env, fieldnames)
			return false unless akismet_ok?(env)
			return false if ip_is_spammer?(env)
			# TODO: stop here, let router handle this:
			name, email, comment = extract(env, fieldnames)
			db_api.add_comment(uri, name, email, comment)
		end

		# PUBLIC: Returns false if bad, hash if done
		# PARAMS: Rack request of posted form, db_api = B50D::Peeps.new
		def mailinglist(env, db_api)
			fieldnames = %w(name email listype)
			refer_reg = %r{\Ahttps?://sivers\.(dev|org)/}
			raise 'reg' unless refer_reg === env['HTTP_REFERER']
			raise 'fields' unless has_these_fields?(env, fieldnames)
			raise 'spammer' if ip_is_spammer?(env)
			# TODO: stop here, let router handle this:
			name, email, listype = extract(env, fieldnames)
			db_api.list_update(name, email, listype)
		end

		# Make sure these fields exist and have stuff in them
		def has_these_fields?(env, fieldnames)
			return false unless env['rack.request.form_hash'].instance_of?(Hash)
			fieldnames.each do |fieldname|
				value = env['rack.request.form_hash'][fieldname]
				return false unless value && value.size > 0
				if fieldname.include? 'email'
					return false unless /\A\S+@\S+\.\S+\Z/ === value.strip
				end
			end
			true
		end

		# Project Honeypot DNS lookup of commenter's IP
		def ip_is_spammer?(env)
			ip = env['REMOTE_ADDR']
			addr = '%s.%s.dnsbl.httpbl.org' %
				[C50E.config[:project_honeypot_key], ip.split('.').reverse.join('.')]
			begin
				Timeout::timeout(1) do
					response = Resolv::DNS.new.getaddress(addr).to_s
					if /127\.[0-9]+\.([0-9]+)\.[0-9]+/.match response
						return true if $1.to_i > 5
					end
					false
				end
			rescue
				false
			end
		end

		# Akismet analysis of comment
		def akismet_ok?(env)
			params = { blog: 'http://sivers.org/',
				user_ip: env['REMOTE_ADDR'],
				user_agent: env['HTTP_USER_AGENT'],
				referrer: env['HTTP_REFERER'],
				permalink: env['HTTP_REFERER'],
				comment_type: 'comment',
				comment_author: env['rack.request.form_hash']['name'],
				comment_author_email: env['rack.request.form_hash']['email'],
				comment_content: env['rack.request.form_hash']['comment'],
				blog_charset: 'UTF-8'}
			params.each {|k,v| params[k] = URI.encode_www_form_component(v)}
			key = C50E.config[:akismet]
			uri = URI("http://#{key}.rest.akismet.com/1.1/comment-check")
			'true' != Net::HTTP.post_form(uri, params).body
		end

		# give string array of fieldnames, get array of these form-posted values back
		def extract(env, fieldnames)
			tags = %r{</?[^>]+?>}    # strip HTML tags
			fieldnames.map do |f|
				env['rack.request.form_hash'][f].force_encoding('UTF-8').strip.gsub(tags, '')
			end
		end

	end
end
