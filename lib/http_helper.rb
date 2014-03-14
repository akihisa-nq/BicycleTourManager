# coding: utf-8

require "uri"
require "net/http"
require "net/https"

module BTM
	module Http
		def self.fetch_https(uri_str, limit = 10)
			raise ArgumentError, 'HTTP redirect too deep' if limit == 0

			uri = URI.parse(uri_str)
			request = Net::HTTP::Get.new(uri_str)
			request.add_field('User-Agent', 'My User Agent Dawg')

			https = Net::HTTP.new(uri.host, uri.port)
			https.use_ssl = true
			https.verify_mode = OpenSSL::SSL::VERIFY_NONE
			https.verify_depth = 5

			https.start do
				response = https.request(request)

				case response
				when Net::HTTPSuccess
					response.body
				else
					response.value
				end
			end
		end

		def self.fetch(uri_str, param, limit = 10)
			raise ArgumentError, 'HTTP redirect too deep' if limit == 0

			uri_str += "?" + param.map {|v| URI.encode(v[0] + "=" + v[1].to_s) }.join("&")

			uri = URI.parse(uri_str)
			request = Net::HTTP::Get.new(uri_str)
			request.add_field('User-Agent', 'My User Agent Dawg')

			response = Net::HTTP.start(uri.host, uri.port) {|http| http.request(request) }
			case response
			when Net::HTTPSuccess
				response.body
			else
				response.value
			end
		end
	end
end

