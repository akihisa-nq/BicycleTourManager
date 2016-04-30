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
		end

		def parse_uri(uri)
			parsed = parse_uri_new(uri)
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
				current = 1

				lon = 0.0
				data.split("!").each do |r|
					case r
					when /^1d(.*)/
						lon = $1.to_f
					when /^2d(.*)/
						pt = Point.new( $1.to_f, lon )

						if current + 1 < obj.points.size
							while current + 1 < obj.points.size
								# A -> pt -> B -> C
								dis_1 = obj.points[current - 1].distance(pt) + obj.points[current].distance(pt) \
									+ obj.points[current].distance(obj.points[current + 1])
								# A -> B -> pt -> C
								dis_2 = obj.points[current - 1].distance(obj.points[current]) \
									+ obj.points[current].distance(pt) + obj.points[current + 1].distance(pt)
								if dis_1 < dis_2
									break
								end

								current += 1
							end
						end

						obj.points.insert(current, pt)
						obj.via << current
						current += 1
					end
				end
			end

			obj
		end
	end
end
