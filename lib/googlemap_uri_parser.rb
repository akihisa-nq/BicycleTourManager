# coding: utf-8

require "uri"
require "http_helper"
require "pstore"

module BTM
	class GoogleMapUriParser
		def initialize(cache_file)
			@cache_file = cache_file
		end

		def parse_uri(uri)
			data = URI.parse(uri)
			data = Hash[*data.query.split(/[&=]/)]

			data["saddr"] = URI.decode(data["saddr"])
			data["daddr"] = URI.decode(data["daddr"]).split("+to:")

			if data.include?("via")
				data["via"] = data["via"].split(",").map{|i| i.to_i } 
			else
				data["via"] = []
			end

			data["geocode"] = URI.decode(data["geocode"]).split(";").map {|i| parse_geocode(i) }

			data
		end

		private

		def parse_geocode(geocode)
			data = nil

			@cache = PStore.new(@cache_file)
			@cache.transaction do
				if @cache[geocode].nil?
					res = Http::fetch_https(%Q|https://maps.google.co.jp/maps?saddr=1&daddr=2&geocode=#{geocode}%3B#{geocode}&dirflg=w|)
					if res =~ /latlng:{lat:([\d\.]+),lng:([\d\.]+)}/
						data = [ $1.to_f, $2.to_f ]
					else
						data = [ 0.0, 0.0 ]
					end

					@cache[geocode] = data
					@cache.commit
				else
					data = @cache[geocode]
				end
			end

			data
		end
	end
end
