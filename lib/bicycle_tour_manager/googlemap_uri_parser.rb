# coding: utf-8

require "uri"
require "pstore"

require "bicycle_tour_manager/route"
require "bicycle_tour_manager/http_helper"

module BTM
	class GoogleMapUri
		def initialize
			@start = ""
			@dest = ""
			@via = []
			@geocode = Point.new(0.0, 0.0, 0.0)
		end

		attr_accessor :start, :dest, :via, :geocode
	end

	class GoogleMapUriParser
		def initialize(geocode_cache)
			@geocode_cache = geocode_cache
		end

		def parse_uri(uri)
			obj = split_uri(uri)
			create_routes(obj)
		end

		private

		def create_routes(obj)
			route = Route.new

			path = Path.new
			path.start = obj.geocode[0]

			current = 0
			via_current = 0
			(obj.geocode.size - 1).times do |i|
				if obj.via.size > via_current && obj.via[via_current] == i + 1
					path.way_points << obj.geocode[i + 1]
					via_current += 1
				else
					path.end = obj.geocode[i + 1]
					route.path_list << path

					path = Path.new
					path.start = obj.geocode[i + 1]
				end
			end

			route
		end

		def split_uri(uri)
			parsed_uri = URI.parse(uri)
			data = Hash[*parsed_uri.query.split(/[&=]/)]
			uri = GoogleMapUri.new

			uri.start = URI.decode(data["saddr"])
			uri.dest = URI.decode(data["daddr"]).split("+to:")

			if data.include?("via")
				uri.via = data["via"].split(",").map{|i| i.to_i } 
			else
				uri.via = []
			end

			uri.geocode = URI.decode(data["geocode"]).split(";").map {|i| parse_geocode(i) }

			uri
		end

		def parse_geocode(geocode)
			data = nil

			cache = PStore.new(@geocode_cache)
			cache.transaction do
				if cache[geocode].nil?
					data = Http::fetch_https(%Q|https://maps.google.co.jp/maps?saddr=1&daddr=2&geocode=#{geocode}%3B#{geocode}&dirflg=w|)
					cache[geocode] = data
					cache.commit
				else
					data = cache[geocode]
				end
			end

			if data =~ /latlng:{lat:([\d\.]+),lng:([\d\.]+)}/
				Point.new($1.to_f, $2.to_f)
			else
				Point.new(0.0, 0.0)
			end
		end
	end
end
