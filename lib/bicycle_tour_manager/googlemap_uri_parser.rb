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
					pt = i.split(",").map {|s| s.to_f }
					Point.new(*pt)
				end
			end

			if /data=(.*)\?/ =~ uri
				data = $1[6..-1]
				current = 1

				order = data.scan(/!1m\d+/)
				if order.count > 0
					order.delete_at(order.count - 1)
					order = order.delete_if {|a| a == "!1m2" }

					via = []
					data.scan(/!1d-?\d+.\d+!2d-?\d+.\d+/) do |v|
						g = v[3..-1].split("!2d" ).map {|s| s.to_f }.reverse
						via << Point.new( *g )
					end

					via_index = 0
					order.each do |step|
						iter = step[3..-1].to_i / 5
						iter.times do |i|
							obj.points.insert(current, via[via_index])
							via_index += 1

							obj.via << current
							current += 1
						end

						current += 1
					end
				end
			end

			obj
		end
	end
end
