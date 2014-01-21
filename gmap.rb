# coding: utf-8

require "uri"
require "yaml"
require "net/http"
require "net/https"
require "pstore"
require "open3"

GNUPLOT = ENV["GNUPLOT"]
CACHE_DIR = ENV["BICYCLE_TOUR_MANAGER_CACHE"] || File.dirname(__FILE__)

PEAK_SEARCH_DISTANCE = 2.5
PEAK_LIMIT_DISTANCE = 0.5
PEAK_LIMIT_GRADIENT = 3.0
PEAK_LIMIT_DISTANCE_LONG = 5.0
PEAK_LIMIT_GRADIENT_LONG = 2.0

GRAD_LIMIT_SPLIT_ELEVATION = 37.5
GRAD_LIMIT_GRADIENT = PEAK_LIMIT_GRADIENT.to_i
GRAD_LIMIT_DISTANCE_LONG = 5.0
GRAD_LIMIT_GRADIENT_LONG = 2.0

PLOT_ELEVATION_MIN = -100
PLOT_ELEVATION_MAX = 1100

class Route
	def initialize(start)
		@start = start
		@end = 0
		@way_points = []
		@distance
		@steps = []
	end

	def fetch
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

		cache = PStore.new("#{CACHE_DIR}/cache_route.db")
		cache.transaction do
			if cache[key].nil?
				request = "http://maps.googleapis.com/maps/api/directions/json"
				ret = YAML.load(Http::fetch(request, param))
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
		cache = PStore.new("#{CACHE_DIR}/cache_elevation.db")
		cache.transaction do
			if cache[points].nil?
				request = "http://maps.googleapis.com/maps/api/elevation/json"
				param = {
					"sensor" => "false",
					"locations" => "enc:" + points
				}

				ret = YAML.load(Http::fetch(request, param))["results"]
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

def parse_geocode(geocode)
	data = nil

	cache = PStore.new("#{CACHE_DIR}/cache_geocode.db")
	cache.transaction do
		if cache[geocode].nil?
			res = Http::fetch_https(%Q|https://maps.google.co.jp/maps?saddr=1&daddr=2&geocode=#{geocode}%3B#{geocode}&dirflg=w|)
			if res =~ /latlng:{lat:([\d\.]+),lng:([\d\.]+)}/
				data = [ $1.to_f, $2.to_f ]
			else
				data = [ 0.0, 0.0 ]
			end

			cache[geocode] = data
			cache.commit
		else
			data = cache[geocode]
		end
	end

	data
end

def parse_route_uri(uri)
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

def get_routes(obj)
	route = Route.new(obj["geocode"][0])
	routes = []
	current = 0
	via_current = 0
	(obj["geocode"].size - 1).times do |i|
		if obj["via"].size > via_current && obj["via"][via_current] == i + 1
			route.way_points << obj["geocode"][i + 1]
			via_current += 1
		else
			route.end = obj["geocode"][i + 1]
			routes << route
			route = Route.new(obj["geocode"][i + 1])
		end
	end
	routes
end

def parse_poly(data)
	poly = []
	index = 0
	len = data.length
	lat = 0
	lng = 0

	while index < len
		b = nil
		shift = 0
		result = 0

		begin
			b = data[index].ord - 63
			index += 1
			result |= (b & 0x1f) << shift
			shift += 5;
		end while b >= 0x20

		dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
		lat += dlat

		shift = 0;
		result = 0;
		begin
			b = data[index].ord - 63
			index += 1
			result |= (b & 0x1f) << shift
			shift += 5;
		end while (b >= 0x20)

		dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1))
		lng += dlng

		poly << [lat / 1e5.to_f, lng / 1e5.to_f]
	end

	poly
end

def haversin(theta)
	Math.sin( 0.5 * theta ) ** 2
end

R = 6371.0008 # Earth volumetric radius

def calc_distance(p1,p2)
	lat1, lon1 = [p1[:lat], p1[:lon]].map {|a| a * Math::PI / 180.0}
	lat2, lon2 = [p2[:lat], p2[:lon]].map {|a| a * Math::PI / 180.0}
	deltalat = lat2 - lat1
	deltalon = lon2 - lon1
	h = haversin(deltalat) + Math.cos(lat1) * Math.cos(lat2) * haversin(deltalon)
	2 * R * Math.asin(Math.sqrt(h))
end

def flatten_routes(routes)
	tmp = routes.each.with_index.map do |r, i|
		steps = r.steps[0..-2]
		steps[0][:waypoint] = i + 1
		steps
	end
	tmp = tmp.inject(:+)

	tmp << routes[-1].steps[-1]
	tmp[-1][:waypoint] = routes.size + 1

	prev = tmp[0]
	distance = 0.0
	tmp.each do |r|
		distance += calc_distance(prev, r)
		r[:dis] = distance
		prev = r
	end

	tmp
end

def check_peak(tmp)
	# 極小/極大をマークする
	tmp[0][:min_max] = :mark
	tmp[-1][:min_max] = :mark

	prev = 0
	prev_min = 0
	(1..tmp.length-2).each do |i|
		check_min = true
		check_max = true

		# 最小値チェック
		prev_min = i if tmp[prev_min][:ele] > tmp[i][:ele]

		# 以前の点
		j = i - 1
		while j >= 0 && (check_min || check_max) && calc_distance(tmp[i], tmp[j]) < PEAK_SEARCH_DISTANCE
			check_min = false if tmp[j][:ele] <= tmp[i][:ele]
			check_max = false if tmp[j][:ele] >= tmp[i][:ele]
			j -= 1
		end
		next unless check_min || check_max

		# 以後の点
		j = i + 1
		while j < tmp.length && (check_min || check_max) && calc_distance(tmp[i], tmp[j]) < PEAK_SEARCH_DISTANCE
			check_min = false if tmp[j][:ele] <= tmp[i][:ele]
			check_max = false if tmp[j][:ele] >= tmp[i][:ele]
			j += 1
		end
		next unless check_min || check_max

		# マークする
		if check_min
			if tmp[prev][:min_max] == :mark_min
				if tmp[prev][:ele] < tmp[i][:ele]
					# マーク不要
				else
					tmp[prev].delete(:min_max)
					tmp[i][:min_max] = :mark_min
					prev = i
				end
			else
				tmp[i][:min_max] = :mark_min
				prev = i
			end
		else
			if prev_min > 0 && tmp[prev][:min_max] == :mark_max
				tmp[prev_min][:min_max] = :mark_min
			end

			tmp[i][:min_max] = :mark_max
			prev = i
		end

		prev_min = i
	end

	tmp
end

def check_gradient(tmp)
	result = []

	calc = lambda do |i, j|
		a = (tmp[j][:ele] - tmp[i][:ele]) / (tmp[j][:dis] - tmp[i][:dis])
		b = tmp[i][:ele] - a * tmp[i][:dis]

		if tmp[j][:dis] - tmp[i][:dis] > 1.0
			data = 0
			index = 0

			((i+1)..(j-1)).each do |k|
				ele_calc = a * tmp[k][:dis] + b
				d = (tmp[k][:ele] - ele_calc).abs

				if d >= data
					data = d
					index = k
				end
			end

			if data >= GRAD_LIMIT_SPLIT_ELEVATION
				break calc.call(i, index) + calc.call(index, j)
			end
		end

		break [{
			:start => tmp[i],
			:end => tmp[j],
			:grad => (a / 10.0).to_i
		}]
	end

	prev = 0
	tmp.each.with_index do |e, i|
		unless e[:min_max].nil?
			if e[:min_max] == :mark_max
				ret = calc.call(prev, i)

				current = 0
				while current + 1 < ret.size
					if ret[current][:grad] == ret[current + 1][:grad]
						ret[current][:start] = ret[current][:start]
						ret[current][:end] = ret[current + 1][:end]
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

def plot(routes, outfile)
	graph_data = "graph.data"
	waypoint_data = "waypoint.data"
	peak_data = "peak.data"
	gradient_data = "grad.data"
	gradient_label_data = "grad_label.data"

	# フラット化
	tmp = flatten_routes(routes)

	# ピークをマーク
	tmp = check_peak(tmp)

	# 傾斜を計算
	grads = check_gradient(tmp)

	File.open(graph_data, "w") do |graph|
	File.open(waypoint_data, "w") do |waypoint|
	File.open(peak_data, "w") do |peak|
		# データ ファイルを出力
		prev_waypoint = nil
		prev_peak = nil

		tmp.each.with_index do |pt, i|
			graph << "#{pt[:dis]} #{pt[:ele]}\n"

			if pt.include?(:waypoint)
				if prev_waypoint.nil? \
				  || pt[:dis] - prev_waypoint[:dis] >= 2.5 \
				  || (pt[:ele] - prev_waypoint[:ele]).abs >= 100.0
					waypoint << "#{pt[:dis]} #{pt[:ele]} ★#{pt[:waypoint]}\\n\n"
					prev_waypoint = pt
				end
			end

			if pt.include?(:min_max)
				if pt[:min_max] == :mark_max
					diff_dis = pt[:dis] - prev_peak[:dis]
					diff_ele = pt[:ele] - prev_peak[:ele]
					grad_val = diff_ele / diff_dis / 10.0

					if diff_dis >= PEAK_LIMIT_DISTANCE && grad_val >= PEAK_LIMIT_GRADIENT || (grad_val >= PEAK_LIMIT_GRADIENT_LONG && diff_dis >= PEAK_LIMIT_DISTANCE_LONG)
						peak << "#{pt[:dis]} #{pt[:ele]} #{pt[:ele].to_i}\n"
					end
				end

				prev_peak = pt
			end
		end
	end; end; end

	File.open(gradient_data, "w") do |grad|
	File.open(gradient_label_data, "w") do |grad_label|
		grads.each do |e|
			diff_dis = e[:end][:dis] - e[:start][:dis]

			if e[:grad] >= GRAD_LIMIT_GRADIENT || (e[:grad] >= GRAD_LIMIT_GRADIENT_LONG && diff_dis >= GRAD_LIMIT_DISTANCE_LONG)
				grad << "#{e[:start][:dis]} #{e[:start][:ele]} -50 #{e[:start][:dis].round}\\n+#{diff_dis.round}\n"
				grad << "#{e[:end][:dis]} #{e[:end][:ele]}\n"
				grad << "\n"

				dis = (e[:start][:dis] + e[:end][:dis]) / 2
				ele = (e[:start][:ele] + e[:end][:ele]) / 2
				grad_label << "#{dis} #{ele} #{e[:grad]}%\n"
			end
		end
	end; end

	Open3.popen3( "\"#{GNUPLOT}\" -persist" ) do |pipe, unused1, unused2, thread|
		unused1.close
		unused2.close

		base_ele = 1200
		image_base_x = 1200
		image_base_y = 300

		image_x = 1200
		max_ele = PLOT_ELEVATION_MAX
		min_ele = PLOT_ELEVATION_MIN
		ele_range = max_ele - min_ele

		image_y = (image_base_y.to_f * ele_range.to_f / base_ele.to_f * image_x.to_f / image_base_x.to_f).to_i

		pipe << "unset key\n"
		pipe << "set grid xtics mxtics ytics\n"
		pipe << "set xtics 5\n"
		pipe << "set ytics 100\n"
		pipe << "set mxtics 2\n"
		pipe << "set mytics 2\n"
		pipe << "show mxtics\n"
		pipe << "show mytics\n"
		pipe << "set xrange [0:120]\n"
		pipe << "set yrange [#{min_ele}:#{max_ele}]\n"
		pipe << "set xlabel 'distance, km'\n"
		pipe << "set ylabel 'elevation, m'\n"
		pipe << "set terminal png size #{image_x},#{image_y} font '#{ENV["FONT"]}'\n"
		pipe << "set output '#{outfile}';\n"
		pipe << "plot '#{graph_data}' u 1:2 w lines lw 3,"
		pipe << "     '#{gradient_data}' u 1:2 w lines lw 3,"
		pipe << "     '#{waypoint_data}' u 1:2 w points ps 3 lw 3,"
		pipe << "     '#{peak_data}' u 1:2 w points ps 2 pt 3 lw 2,"
		pipe << "     '#{waypoint_data}' u 1:2:3 w labels offset 0,-1,"
		pipe << "     '#{peak_data}' u 1:2:3 w labels offset 0,1,"
		pipe << "     '#{gradient_data}' u 1:3:4 w labels,"
		pipe << "     '#{gradient_label_data}' u 1:2:3 w labels center\n"

		pipe << "exit\n"
	end

	sleep(4.0)

	File.delete(graph_data)
	File.delete(waypoint_data)
	File.delete(peak_data)
	File.delete(gradient_data)
	File.delete(gradient_label_data)
end

def dump_gpx(plan, output_file)
	File.open(output_file, "w:utf-8") do |file|
		file << <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
EOF

		plan.each do |pc|
			pc[1].each.with_index do |route, i|
				file << <<EOF
	<wpt lat="#{route.steps[0][:lat]}" lon="#{route.steps[0][:lon]}">
		<ele>#{route.steps[0][:ele]}</ele>
		<name>PC#{pc[0]} - ★#{i + 1}</name>
	</wpt>
EOF
			end
		end

		file << <<EOF
	<wpt lat="#{plan[-1][1][-1].steps[-1][:lat]}" lon="#{plan[-1][1][-1].steps[-1][:lon]}">
		<ele>#{plan[-1][1][-1].steps[-1][:ele]}</ele>
		<name>PC#{plan[-1][0]} - ★#{plan[-1][1].size + 1}</name>
	</wpt>
EOF

		file << <<EOF
	<trk>
EOF

		plan.each do |pc|
			file << <<EOF
		<trkseg>
EOF

			pc[1].each do |route|
				route.steps.each do |s|
					file << <<EOF
			<trkpt lat="#{s[:lat]}" lon="#{s[:lon]}">
				<ele>#{s[:ele]}</ele>
				<time>9999-12-31T00:00:00Z</time>
			</trkpt>
EOF
				end
			end

			file << <<EOF
		</trkseg>
EOF

		end

		file << <<EOF
	</trk>
</gpx>
EOF
	end
end

def dump_route(plan, output_file)
	count = 1

	File.open(output_file, "w:utf-8") do |file|
		file << <<EOF
スタート
+0.01h

EOF

		plan.each do |pc|
			pc[1].each.with_index do |route, j|
				count += 1

				file << <<EOF
★#{j + 2}
+#{route.distance}km

EOF
				if (count % 8) == 0
					file << <<EOF
--

EOF
				end
			end

			count = 0

			file << <<EOF
休み
+0.25h

-- PC#{pc[0]} --

EOF
		end
	end
end

INPUT_FILE = ARGV.shift
INPUT_DIR = File.dirname(INPUT_FILE)

plan = []
File.open(INPUT_FILE, "r:utf-8") do |file|
	file.each_line do |line|
		line.strip!

		if line =~ /^"PC(\d+)":(.*)$/
			obj = parse_route_uri($2)
			routes = get_routes(obj)
			routes.each {|r| r.fetch }
			plan << [$1.to_i, routes]
		end
	end
end
plan.sort_by! {|e| e[0]}

plan.each do |e|
	plot(e[1], "#{INPUT_DIR}/PC#{e[0]}.png")
end
 
dump_gpx(plan, "#{INPUT_DIR}/route.gpx")
dump_route(plan, "#{INPUT_DIR}/route_template.txt")
