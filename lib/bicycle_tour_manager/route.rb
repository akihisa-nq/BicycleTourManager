# coding: utf-8

require "yaml"
require "polylines"
require "rgeo"

module BTM
	COORD_SYS = <<EOS
GEOGCS["WGS 84",
    DATUM["WGS_1984",
        SPHEROID["WGS 84",6378137,298.257223563,
            AUTHORITY["EPSG","7030"]],
        AUTHORITY["EPSG","6326"]],
    PRIMEM["Greenwich",0,
        AUTHORITY["EPSG","8901"]],
    UNIT["degree",0.0174532925199433,
        AUTHORITY["EPSG","9122"]],
    AUTHORITY["EPSG","4326"]]
EOS

	def BTM.factory
		@@factory ||= RGeo::Geos.factory(
			:coord_sys => COORD_SYS,
			:srid => 4326
			)
	end

	class NodeInfo
		def initialize
			@text = ""
			@name = ""
			@road = {}
			@limit_speed = 15.0
			@target_speed = 15.0
			@rest_time = 0.0
			@page_break = false
			@hide = false
		end

		def next_road
			@dest.nil? ? "" : @road[@dest]
		end

		def other_roads
			return "" if @orig.nil?

			@road
				.to_a
				.sort_by{|i| self.class.dir_id(i[0]) }
				.select{|v| v[0] != @orig && v[0] != @dest }
				.map { |v| NodeInfo.relative_dir(@orig, v[0]) + " " + v[1] }
				.join(", ")
		end

		def next_relative_dir
			unless @dest.nil? && @orig.nil?
				self.class.relative_dir(@orig, @dest)
			else
				""
			end 
		end

		def parse_direction(str)
			if /\@(.*)\|(.*)\|(.*)/ =~ str
				road = $1
				dir = $2
				name = $3.strip

				@road = Hash[*road.split(/[:,]/).map{|i| i.strip}]
				@name = name

				if dir =~ /(.*)->(.*)/
					@orig = $1.strip
					@dest = $2.strip
				end

				true
			else
				false
			end
		end

		def valid_direction?
			(@orig.nil? || ! @road[@orig].nil?) && (@dest.nil? || ! @road[@dest].nil?)
		end

		def page_break?
			@page_break
		end

		def hide?
			@hide
		end

		attr_accessor :text, :name, :road, :orig, :dest, :limit_speed, :target_speed, :rest_time, :page_break, :hide

		private

		def self.dir_id(name)
			case name.upcase
			when "N"
				0
			when "NE"
				1
			when "E"
				2
			when "SE"
				3
			when "S"
				4
			when "SW"
				5
			when "W"
				6
			when "NW"
				7
			end
		end

		def self.relative_dir( o, d )
			return "" if o.nil? || d.nil? || o.downcase == "c" || d.downcase == "c"

			diff = dir_id(d) - dir_id(o)
			diff += 8 if diff < 0

			case diff
			when 0
				"後ろ"
			when 1
				"左後"
			when 2
				"左折"
			when 3
				"左前"
			when 4
				"直進"
			when 5
				"右前"
			when 6
				"右折"
			when 7
				"右後"
			end
		end
	end

	class Point
		def initialize(lat, lon, ele=0.0)
			@point_geos = BTM.factory.point(lon, lat)
			@ele = ele
			@time = Time.now
			@waypoint_index = -1
			@distance_from_start = 0.0
			@min_max = nil # nil, :mark, :mark_min, :mark_max
			@info = nil
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

		attr_accessor :point_geos, :ele, :time, :time_target, :waypoint_index, :distance_from_start, :min_max, :info

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
			return if tmp.length == 0

			# 極小/極大をマークする
			tmp[0].min_max = :mark
			tmp[-1].min_max = :mark

			prev = 0
			prev_min = 0
			(1..tmp.length-2).each do |i|
				current = tmp[i]

				check_min = true
				check_max = true

				# 最小値チェック
				prev_min = i if tmp[prev_min].ele > current.ele

				# 以前の点
				tmp[0..(i - 1)].reverse.each do |t|
					# 同じ高度があった場合は、後の点を優先する
					check_min = false if t.ele < current.ele
					check_max = false if t.ele > current.ele
					break unless (check_min || check_max) && current.distance_on_path(t) < PEAK_SEARCH_DISTANCE
				end
				next unless check_min || check_max

				# 以後の点
				tmp[(i+1)..(tmp.length - 1)].each do |t|
					check_min = false if t.ele <= current.ele
					check_max = false if t.ele >= current.ele
					break unless (check_min || check_max) && current.distance_on_path(t) < PEAK_SEARCH_DISTANCE
				end
				next unless check_min || check_max

				# マークする
				if check_min
					if tmp[prev].min_max == :mark_min
						if tmp[prev].ele < current.ele
							# マーク不要
						else
							tmp[prev].min_max = nil
							current.min_max = :mark_min
							prev = i
						end
					else
						current.min_max = :mark_min
						prev = i
					end
				else
					if prev_min > 0 && tmp[prev].min_max == :mark_max
						tmp[prev_min].min_max = :mark_min
					end

					current.min_max = :mark_max
					prev = i
				end

				prev_min = i
			end

			tmp
		end

		def self.check_gradient(tmp)
			result = []

			calc = lambda do |i, j|
				diff_dis = tmp[j].distance_from_start - tmp[i].distance_from_start
				break [] if diff_dis == 0.0

				a = (tmp[j].ele - tmp[i].ele) / diff_dis
				b = tmp[i].ele - a * tmp[i].distance_from_start

				if tmp[j].distance_from_start - tmp[i].distance_from_start > 1.0
					data = 0
					index = 0

					((i+1)..(j-1)).each do |k|
						ele_calc = a * tmp[k].distance_from_start + b
						d = (tmp[k].ele - ele_calc).abs

						if d >= data
							data = d
							index = k
						end
					end

					if data >= GRAD_LIMIT_SPLIT_ELEVATION
						break calc.call(i, index) + calc.call(index, j)
					end
				end

				break [ GradientData.new( tmp[i], tmp[j], (a / 10.0).to_i ) ]
			end

			prev = 0
			tmp.each.with_index do |e, i|
				unless e.min_max.nil?
					if e.min_max == :mark_max
						ret = calc.call(prev, i)
						next if ret.size == 0

						current = 0
						while current + 1 < ret.size
							if ret[current].grad == ret[current + 1].grad
								ret[current].start = ret[current].start
								ret[current].end = ret[current + 1].end
								ret.delete_at(current + 1)
							else
								current += 1
							end
						end

						result += ret
					else
						prev = i
					end
				end
			end

			result
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

			# ルート探索結果もキャッシュしておく
			key = "S:#{param["origin"]}, D:#{param["destination"]}, W:#{param["waypoints"]}"
			data = route_cache.cache(key) do
				request = "http://maps.googleapis.com/maps/api/directions/json"
				BTM::Http::fetch(request, param)
			end 
			route_result = YAML.load(data)["routes"][0]

			@distance = 0
			
			if route_result && route_result["legs"]
				@distance = route_result["legs"].map {|i| i["distance"]["value"].to_f / 1000.0 }.inject(:+)
			end

			# 高度情報はキャッシュしておく
			if @distance > 0
				fetch_elevation_internal(0, route_result["overview_polyline"]["points"], elevation_cache)
			end
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

		def mark_peak?
			@mark_peak
		end

		def check_distance_from_start(offset)
			unless mark_distance_from_start?
				prev = @steps.first
				dis = offset
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

		def elevation_minmax
			@steps.minmax_by {|s| s.ele }.map {|s| s.ele }
		end

		attr_accessor :start, :end
		attr_reader :way_points, :steps, :distance

		private

		LOC_PER_REQUEST = 256

		PEAK_SEARCH_DISTANCE = 2.5

		GRAD_LIMIT_SPLIT_ELEVATION = 37.5

		def fetch_elevation_internal(start_index, points, elevation_cache)
			data = elevation_cache.cache(points) do
				request = "http://maps.googleapis.com/maps/api/elevation/json"
				param = {
					"sensor" => "false",
					"locations" => "enc:" + points
				}

				BTM::Http::fetch(request, param)
			end
			elevation_result = YAML.load(data)["results"]

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
			tmp = @path_list.map.with_index do |r, i|
				if r.steps.length == 1
					[]
				else
					steps = r.steps[0..-2].map {|s| s.dup }
					steps[0].waypoint_index = i + 1
					steps
				end
			end
			tmp = tmp.inject(:+)

			tmp << @path_list[-1].steps[-1].dup
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

		def elevation_minmax
			@path_list.map {|p| p.elevation_minmax }.flatten.minmax
		end

		def check_distance_from_start(offset)
			@path_list.each do |path|
				path.check_distance_from_start(offset)
				offset = path.steps.last.distance_from_start
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
			@resources = []
			@schedule = []
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
			return [] if routes.length == 0

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

		def total_elevation
			pts = flatten
			Path.check_peak(pts)

			elevation = 0.0
			prev = nil
			pts.each do |s|
				if s.min_max == :mark_max
					elevation += s.ele - prev.ele
					prev = nil
				elsif s.min_max_marked? && (prev.nil? || prev.ele > s.ele)
					prev = s
				end
			end

			elevation
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

		def elevation_minmax
			@routes.map {|r| r.elevation_minmax }.flatten.minmax
		end

		def check_distance_from_start
			offset = 0.0
			@routes.each do |route|
				route.check_distance_from_start(offset)
				offset = route.path_list.last.steps.last.distance_from_start
			end
		end

		attr_reader :routes
		attr_accessor :name, :start_date, :finish_date, :original_file_path, :resources, :schedule
	end

	class GradientData
		def initialize(start, end_, grad)
			@start = start
			@end = end_
			@grad = grad
		end

		attr_accessor :start, :end, :grad
	end

	class Resource
		def initialize( name, amount, recovery_interval, buffer )
			@name = name
			@amount = amount
			@interval = recovery_interval
			@buffer = buffer
		end

		attr_reader :name, :interval, :amount, :buffer
	end

	class Schedule
		def initialize( name, start, interval, res, amount )
			@name = name
			@start_time = start
			@interval = interval
			@resource = res
			@amount = amount
		end

		def fire?(prev, now)
			n = ((now - start_time) / interval).to_i
			return false if n <= 0

			cur = start_time + n * interval
			return prev < cur && cur <= now
		end

		attr_reader :name, :start_time, :interval, :resource, :amount
	end
end
