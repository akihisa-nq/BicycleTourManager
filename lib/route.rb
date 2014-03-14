# coding: utf-8

module BTM
	class Route
		def initialize(start)
			@start = start
			@end = 0
			@way_points = []
			@distance
			@steps = []
		end

		def fetch(route_cache, elevation_cache)
			param = {
				"origin" => @start.join(","),
				"destination" => @end.join(","),
				"sensor" => false,
				"mode" => "walking"
			}
			param["waypoints"] = @way_points.map {|i| i.join(",") }.join("|") if @way_points.length > 0
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
					@steps = ret.map {|i| { :lat => i["location"]["lat"], :lon => i["location"]["lng"], :ele => i["elevation"] } }

					cache[points] = @steps
					cache.commit
				else
					@steps = cache[points]
				end
			end
		end

		attr_accessor :end
		attr_reader :start, :way_points, :steps, :distance
	end
end
