# coding: utf-8

require "yaml"

module BTM
	class Point
		def initialize(lat, lon, ele=0.0)
			@lat = lat
			@lon = lon
			@ele = ele
			@waypoint_index = -1
			@distance_from_start = 0.0
			@min_max = nil # nil, :mark, :mark_min, :mark_max
		end

		def self.from_params(params)
			Point.new(
				params["lat"],
				params["lng"]
				)
		end

		def pack
			"#{@lat},#{@lon}"
		end

		def waypoint?
			@waypoint_index >= 0
		end

		def min_max_marked?
			! @min_max.nil?
		end

		attr_accessor :lat, :lon, :ele, :waypoint_index, :distance_from_start, :min_max
	end

	class Path
		R = 6371.0008 # Earth volumetric radius

		def self.haversin(theta)
			Math.sin( 0.5 * theta ) ** 2
		end

		def self.calc_distance(p1, p2)
			lat1, lon1 = [p1.lat, p1.lon].map {|a| a * Math::PI / 180.0}
			lat2, lon2 = [p2.lat, p2.lon].map {|a| a * Math::PI / 180.0}
			deltalat = lat2 - lat1
			deltalon = lon2 - lon1
			h = haversin(deltalat) + Math.cos(lat1) * Math.cos(lat2) * haversin(deltalon)
			2 * R * Math.asin(Math.sqrt(h))
		end

		def initialize
			@start = Point.new(0.0, 0.0, 0.0)
			@end = Point.new(0.0, 0.0, 0.0)
			@way_points = []
			@distance
			@steps = []
		end

		# この関数を呼ぶ前に start, end, waypoints を設定すること
		def fetch_elevation(route_cache, elevation_cache)
			param = {
				"origin" => @start.pack,
				"destination" => @end.pack,
				"sensor" => false,
				"mode" => "walking"
			}
			param["waypoints"] = @way_points.map {|i| i.pack }.join("|") if @way_points.length > 0

			key = "S:#{param["origin"]}, D:#{param["destination"]}, W:#{param["waypoints"]}"

			# ルート探索結果もキャッシュしておく
			route_result = nil

			cache = PStore.new(route_cache)
			cache.transaction do
				if cache[key].nil?
					request = "http://maps.googleapis.com/maps/api/directions/json"
					ret = YAML.load(BTM::Http::fetch(request, param))
					route_result = ret["routes"][0]

					cache[key] = route_result
					cache.commit
				else
					route_result = cache[key]
				end
			end

			@distance = route_result["legs"].map {|i| i["distance"]["value"].to_f / 1000.0 }.inject(:+)

			# 高度情報はキャッシュしておく
			points = route_result["overview_polyline"]["points"]
			cache = PStore.new(elevation_cache)
			cache.transaction do
				if cache[points].nil?
					request = "http://maps.googleapis.com/maps/api/elevation/json"
					param = {
						"sensor" => "false",
						"locations" => "enc:" + points
					}

					ret = YAML.load(BTM::Http::fetch(request, param))["results"]
					@steps = ret.map do |i|
							pt = Point.from_params(i["location"])
							pt.ele = i["elevation"]
							pt
						end

					cache[points] = @steps
					cache.commit
				else
					@steps = cache[points]
				end
			end
		end

		attr_accessor :start, :end
		attr_reader :way_points, :steps, :distance
	end

	class Route
		def initialize
			@path_list = []
			@index = -1
		end

		def flatten
			tmp = @path_list.each.with_index.map do |r, i|
				steps = r.steps[0..-2]
				steps[0].waypoint_index = i + 1
				steps
			end
			tmp = tmp.inject(:+)

			tmp << @path_list[-1].steps[-1]
			tmp[-1].waypoint_index = @path_list.size + 1

			prev = tmp[0]
			distance = 0.0
			tmp.each do |r|
				distance += Path.calc_distance(prev, r)
				r.distance_from_start = distance
				prev = r
			end

			tmp
		end

		def fetch_elevation(cache_route, cache_elevation)
			@path_list.each do |r|
				r.fetch_elevation(cache_route, cache_elevation)
			end
		end

		attr_reader :path_list
		attr_accessor :index
	end

	class Tour
		def initialize
			@routes = []
			@name = ""
			@start_date = Time.now
			@finish_date = Time.now
			@original_file_path = ""
		end

		def sort!
			@routes.sort_by! {|i| i.index }
		end

		attr_reader :routes
		attr_accessor :name, :start_date, :finish_date, :original_file_path
	end
end