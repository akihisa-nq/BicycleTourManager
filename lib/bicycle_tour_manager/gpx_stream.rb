# coding: utf-8

require "nokogiri"
require "time"

require "bicycle_tour_manager/route"

module BTM
	class GpxStream
		STATE_START = -1
		STATE_METADATA = 0
		STATE_METADATA_TIME = 1
		STATE_TRK = 2
		STATE_TRK_NAME = 3
		STATE_TRKPT = 4
		STATE_TRKPT_TIME = 5
		STATE_TRKPT_ELE = 6
		STATE_WPT = 7
		STATE_WPT_TIME = 8
		STATE_WPT_ELE = 9

		def self.read(path)
			tour = read_from_stream(File.open(path, "r:utf-8"))
			tour.original_file_path = path
			tour
		end

		def self.read_from_stream(stream)
			tour = Tour.new

			if stream.respond_to?(:original_filename)
				tour.original_file_path = stream.original_filename
			end

			route = Route.new
			route.path_list << Path.new

			state = STATE_START
			reader = Nokogiri::XML::Reader(stream)
			reader.each do |node|
				case node.name
				when "metadata"
					if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
						state = STATE_METADATA
					else
						state = STATE_START
					end

				when "trk"
					if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
						state = STATE_TRK
					else
						state = STATE_START
					end

				when "name"
					if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
						state = STATE_TRK_NAME if state == STATE_TRK
					else
						state = STATE_TRK if state = STATE_TRK_NAME
					end

				when "time"
					if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
						state = STATE_METADATA_TIME if state == STATE_METADATA || state == STATE_START
						state = STATE_TRKPT_TIME if state == STATE_TRKPT
						state = STATE_WPT_TIME if state == STATE_WPT
					else
						state = STATE_METADATA if state == STATE_METADATA_TIME
						state = STATE_TRKPT if state == STATE_TRKPT_TIME
						state = STATE_WPT if state == STATE_WPT_TIME
					end

				when "trkseg"
					if node.node_type == Nokogiri::XML::Reader::TYPE_END_ELEMENT
						tour.routes << route

						route = Route.new
						route.path_list << Path.new
					end

				when "trkpt"
					if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
						state = STATE_TRKPT
						route.path_list.last.steps << Point.new(
							node.attributes["lat"].to_f,
							node.attributes["lon"].to_f
							)
					end

				when "wpt"
					if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
						state = STATE_WPT
						route.path_list.last.way_points << Point.new(
							node.attributes["lat"].to_f,
							node.attributes["lon"].to_f
							)
					end

				when "ele"
					if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
						state = STATE_TRKPT_ELE if state == STATE_TRKPT
						state = STATE_WPT_ELE if state == STATE_WPT
					else
						state = STATE_TRKPT if state == STATE_TRKPT_ELE
						state = STATE_WPT if state == STATE_WPT_ELE
					end

				when "#text"
					case state
					when STATE_TRK_NAME
						tour.name = node.value
					when STATE_METADATA_TIME
						tour.start_date = Time.parse(node.value)
					when STATE_TRKPT_TIME
						route.path_list.last.steps.last.time = Time.parse(node.value)
					when STATE_TRKPT_ELE
						route.path_list.last.steps.last.ele = node.value.to_f
					when STATE_WPT_TIME
						route.path_list.last.way_points.last.time = Time.parse(node.value)
					when STATE_WPT_ELE
						route.path_list.last.way_points.last.ele = node.value.to_f
					end
				end
			end

			tour.set_start_end

			tour
		end

		def self.write_routes(output_file, tour)
			File.open(output_file, "w:utf-8") do |file|
				write_routes_to_stream(file, tour)
			end
		end

		def self.write_routes_to_stream(file, tour)
			file << <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
	<metadata>
EOF

			if tour.start_date
				file << <<EOF
		<time>#{tour.start_date.getutc.strftime("%Y-%m-%dT%H:%M:%SZ")}</time>
EOF
			end

			file << <<EOF
	</metadata>
EOF

			tour.routes.each do |pc|
				i = 1
				pc.path_list.each do |route|
					route.way_points.each do |wpt|
						write_way_point(file, pc.index, wpt, i)
						i += 1
					end
				end
			end

			file << <<EOF
	<trk>
		<name>#{tour.name}</name>
EOF

			tour.routes.each do |pc|
				file << <<EOF
		<trkseg>
EOF

				pc.path_list.each do |route|
					route.steps.each do |s|
						file << <<EOF
			<trkpt lat="#{s.lat}" lon="#{s.lon}">
				<ele>#{s.ele}</ele>
EOF
						if s.time
							file << <<EOF
				<time>#{s.time.getutc.strftime("%Y-%m-%dT%H:%M:%SZ")}</time>
EOF
						else
							file << <<EOF
				<time>9999-12-31T00:00:00Z</time>
EOF
						end

						file << <<EOF
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

		private

		def self.write_way_point(file, pc_index, wpt, index)
			file << <<EOF
	<wpt lat="#{wpt.lat}" lon="#{wpt.lon}">
		<ele>#{wpt.ele}</ele>
EOF

			if wpt.time
				file << <<EOF
		<time>#{wpt.time.getutc.strftime("%Y-%m-%dT%H:%M:%SZ")}</time>
EOF
			end

			file << <<EOF
		<name>PC#{pc_index} - ★#{index}</name>
	</wpt>
EOF
		end
	end
end

