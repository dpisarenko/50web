require 'net/http'
require 'resolv'

# README: http://akismet.com/development/api/#comment-check
def akismet_ok?(api_key, params)
	params.each {|k,v| params[k] = URI.encode_www_form_component(v)}
	uri = URI("http://#{api_key}.rest.akismet.com/1.1/comment-check")
	'true' != Net::HTTP.post_form(uri, params).body
end

# README: http://www.projecthoneypot.org/httpbl_api.php
def honeypot_ok?(api_key, ip)
	addr = '%s.%s.dnsbl.httpbl.org' %
		[api_key, ip.split('.').reverse.join('.')]
	begin
		Timeout::timeout(1) do
			response = Resolv::DNS.new.getaddress(addr).to_s
			if /127\.[0-9]+\.([0-9]+)\.[0-9]+/.match response
				return false if $1.to_i > 5
			end
		end
		true
	rescue
		true
	end
end

