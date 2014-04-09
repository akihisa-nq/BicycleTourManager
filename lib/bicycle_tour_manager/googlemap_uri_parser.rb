# coding: utf-8

require "uri"

require "bicycle_tour_manager/route"
require "bicycle_tour_manager/http_helper"

module BTM
	class GoogleMapUri
		def initialize
			@start = ""
			@dest = ""
			@via = []
			@points = []
		end

		attr_accessor :start, :dest, :via, :points
	end

	class GoogleMapUriParser
		def initialize(geocode_cache)
			@geocode_cache = geocode_cache
		end

		def parse_uri(uri)
			parsed = nil
			if uri.include?("/dir/")
				parsed = parse_uri_new(uri)
			else
				parsed = parse_uri_old(uri)
			end
			create_routes(parsed)
		end

		private

		def create_routes(obj)
			route = Route.new

			path = Path.new
			path.start = obj.points[0]

			current = 0
			via_current = 0
			(obj.points.size - 1).times do |i|
				cur = i + 1

				if obj.via.size > via_current && obj.via[via_current] == cur
					path.way_points << obj.points[cur]
					via_current += 1
				else
					path.end = obj.points[cur]
					route.path_list << path

					path = Path.new
					path.start = obj.points[cur]
				end
			end

			route
		end

		def parse_uri_old(uri)
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

			uri.points = URI.decode(data["geocode"]).split(";").map {|i| parse_geocode(i) }

			uri
		end

		def parse_uri_new(uri)
			obj = GoogleMapUri.new

			if /\/dir\/(.*)\/@/ =~ uri
				obj.points = $1.split("/").map do |i|
					p = i.split(",")
					Point.new(p[0].to_f, p[1].to_f)
				end
			end

			if /data=(.*)\?/ =~ uri
				data = $1
				current = 0

				lon = 0.0
				data.split("!").each do |r|
					case r
					when /^1d(.*)/
						lon = $1.to_f
					when /^2d(.*)/
						pt = Point.new( $1.to_f, lon )
						dis = obj.points[current].distance(pt)

						while current + 2 < obj.points.length
							cur = obj.points[current + 1].distance(pt)
							if dis < cur
								break
							end

							dis = cur
							current += 1
						end

						if current >= 1
							dis_1 = obj.points[current - 1].distance(pt) + obj.points[current].distance(obj.points[current + 1])
							dis_2 = obj.points[current + 1].distance(pt) + obj.points[current].distance(obj.points[current - 1])
							if dis_1 < dis_2
								current -= 1
							end
						end

						current += 1
						obj.points.insert(current, pt)
						obj.via << current
					end
				end
			end

			obj
		end

		def parse_geocode(geocode)
			data = @geocode_cache.cache(geocode) do
				ret = Http::fetch_https(%Q|https://maps.google.co.jp/maps?saddr=1&daddr=2&geocode=#{geocode}%3B#{geocode}&dirflg=w|)

				if ret =~ /latlng:{lat:([\d\.]+),lng:([\d\.]+)}/
					BTM.factory.point($2.to_f, $1.to_f)
				else
					BTM.factory.point(0.0, 0.0)
				end
			end

			Point.new(data.y, data.x)
		end
	end
end
