# coding: utf-8

require "yaml"
require "polylines"
require "rgeo"

module BTM
	def BTM.factory
		@@factory ||= RGeo::Geos.factory(
			:srs_database => RGeo::CoordSys::SRSDatabase::SrOrg.new('epsg'),
			:srid => 4326
			)
	end

	class Point
		def initialize(lat, lon, ele=0.0)
			@point_geos = BTM.factory.point(lon, lat)
			@ele = ele
			@time = Time.now
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
			"#{lat},#{lon}"
		end

		def waypoint?
			@waypoint_index >= 0
		end

		def min_max_marked?
			! @min_max.nil?
		end

		def lat
			@point_geos.y
		end

		def lat=(val)
			@point_geos.y = val
		end

		def lon
			@point_geos.x
		end

		def lon=(val)
			@point_geos.x = val
		end

		def distance(pt)
			Point.calc_distance(self, pt)
		end

		def distance_on_path(pt)
			(self.distance_from_start - pt.distance_from_start).abs
		end

		attr_accessor :point_geos, :ele, :time, :waypoint_index, :distance_from_start, :min_max

		private

		R1 = 6378.137000
		R2 = 6356.752314245
		E_2 = (R1 ** 2 - R2 ** 2) / (R1 ** 2)

		def self.calc_distance(p1, p2)
			lat1, lon1 = [p1.lat, p1.lon].map {|a| a * Math::PI / 180.0}
			lat2, lon2 = [p2.lat, p2.lon].map {|a| a * Math::PI / 180.0}
			dy = lat2 - lat1
			dx = lon2 - lon1
			uy = (lat2 + lat1) / 2.0
			rot_w = Math.sqrt(1.0  - E_2 * (Math.sin(uy) ** 2))
			m = R1 * (1 - E_2) * (rot_w ** 3)
			n = R1 * rot_w
			Math.sqrt( (dy * m) ** 2 + (dx * n * Math.cos(uy)) ** 2 )
		end
	end

	class Path
		def self.check_peak(tmp)
			# 極小/極大をマークする
			tmp[0].min_max = :mark
			tmp[-1].min_max = :mark

			prev = 0
			prev_min = 0
			(1..tmp.length-2).each do |i|
				check_min = true
				check_max = true

				# 最小値チェック
				prev_min = i if tmp[prev_min].ele > tmp[i].ele

				# 以前の点
				j = i - 1
				while j >= 0 && (check_min || check_max) && tmp[i].distance_on_path(tmp[j]) < PEAK_SEARCH_DISTANCE
					check_min = false if tmp[j].ele <= tmp[i].ele
					check_max = false if tmp[j].ele >= tmp[i].ele
					j -= 1
				end
				next unless check_min || check_max

				# 以後の点
				j = i + 1
				while j < tmp.length && (check_min || check_max) && tmp[i].distance_on_path(tmp[j]) < PEAK_SEARCH_DISTANCE
					check_min = false if tmp[j].ele <= tmp[i].ele
					check_max = false if tmp[j].ele >= tmp[i].ele
					j += 1
				end
				next unless check_min || check_max

				# マークする
				if check_min
					if tmp[prev].min_max == :mark_min
						if tmp[prev].ele < tmp[i].ele
							# マーク不要
						else
							tmp[prev].min_max = nil
							tmp[i].min_max = :mark_min
							prev = i
						end
					else
						tmp[i].min_max = :mark_min
						prev = i
					end
				else
					if prev_min > 0 && tmp[prev].min_max == :mark_max
						tmp[prev_min].min_max = :mark_min
					end

					tmp[i].min_max = :mark_max
					prev = i
				end

				prev_min = i
			end

			tmp
		end

		def initialize
			@start = Point.new(0.0, 0.0, 0.0)
			@end = Point.new(0.0, 0.0, 0.0)
			@way_points = []
			@distance = 0.0
			@steps = []
			@mark_peak
			@mark_distance_from_start
		end

		# この関数を呼ぶ前に start, end, way_points を設定すること
		def search_route(route_cache, elevation_cache)
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
			fetch_elevation_internal(0, route_result["overview_polyline"]["points"], elevation_cache)
		end

		def fetch_elevation(elevation_cache)
			(((@steps.count - 1) / LOC_PER_REQUEST) + 1).times do |i|
				points = Polylines::Encoder.encode_points(@steps[i * LOC_PER_REQUEST, LOC_PER_REQUEST].map {|pt| [pt.lat, pt.lon]})
				fetch_elevation_internal(i * LOC_PER_REQUEST, points, elevation_cache)
			end
		end

		def set_start_end
			@start = @steps[0]
			@end = @steps[-1]

			if @distance == 0.0
				(@steps.count - 2).times do |i|
					@distance += @steps[i + 1].distance(@steps[i])
				end
			end
		end

		def delete_by_distance(pt, dis)
			@steps.delete_if {|p| p.distance(pt) < dis }
		end

		def check_peak
			check_distance_from_start

			unless mark_peak?
				Path.check_peak(@steps)
			end
		end

		def mark_peak?
			@mark_peak
		end

		def check_distance_from_start
			unless mark_distance_from_start?
				prev = @steps.first
				dis = 0.0
				@steps.each do |s|
					dis += prev.distance(s)
					s.distance_from_start = dis
					prev = s
				end
			end
		end

		def mark_peak=(flag)
			@mark_peak = flag
		end

		def mark_distance_from_start?
			@mark_distance_from_start
		end

		def mark_distance_from_start=(flag)
			@mark_distance_from_start = flag
		end

		attr_accessor :start, :end
		attr_reader :way_points, :steps, :distance

		private

		LOC_PER_REQUEST = 256

		PEAK_SEARCH_DISTANCE = 2.5

		def fetch_elevation_internal(start_index, points, elevation_cache)
			elevation_result = nil

			cache = PStore.new(elevation_cache)
			cache.transaction do
				if cache[points].nil?
					request = "http://maps.googleapis.com/maps/api/elevation/json"
					param = {
						"sensor" => "false",
						"locations" => "enc:" + points
					}

					elevation_result = YAML.load(BTM::Http::fetch(request, param))["results"]

					cache[points] = elevation_result
					cache.commit
				else
					elevation_result = cache[points]
				end
			end

			@steps[start_index, elevation_result.count] = elevation_result.map do |i|
					pt = Point.from_params(i["location"])
					pt.ele = i["elevation"]
					pt
				end
		end
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
			tmp.each do |s|
				distance += prev.distance(s)
				s.distance_from_start = distance
				prev = s
			end

			tmp
		end

		def search_route(route_cache, cache_elevation)
			@path_list.each do |r|
				r.search_route(route_cache, cache_elevation)
			end
		end

		def fetch_elevation(cache_elevation)
			@path_list.each do |r|
				r.fetch_elevation(cache_elevation)
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

		def set_start_end
			@routes.each do |r|
				r.path_list.each do |p|
					p.set_start_end
				end
			end
		end

		def flatten
			offset = 0.0

			routes.map.with_index { |r, i|
				f = r.flatten

				f.each do |p|
					if p.waypoint_index > 0
						p.waypoint_index += 100 * i
					end

					p.distance_from_start += offset
				end
				offset = f.last.distance_from_start

				f
			}.inject(:+)
		end

		def total_distance
			if routes.length == 0
				0.0
			else
				routes.map {|r| r.path_list.map {|p| p.distance }.inject(:+) }.inject(:+)
			end
		end

		def delete_by_distance(pt, dis)
			routes.each do |r|
				r.path_list.each do |p|
					p.delete_by_distance(pt, dis)
				end
				r.path_list.delete_if {|p| p.steps.count == 0 }
			end
			routes.delete_if {|r| r.path_list.count == 0 }
		end

		attr_reader :routes
		attr_accessor :name, :start_date, :finish_date, :original_file_path
	end
end
