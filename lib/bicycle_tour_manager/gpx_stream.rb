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

		def self.read(path)
			tour = Tour.new
			tour.original_file_path = path

			route = Route.new
			route.path_list << Path.new

			state = STATE_START
			reader = Nokogiri::XML::Reader(File.open(path))
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
						state = STATE_METADATA_TIME if state == STATE_METADATA
						state = STATE_TRKPT_TIME if state == STATE_TRKPT
					else
						state = STATE_METADATA if state == STATE_METADATA_TIME
						state = STATE_TRKPT if state == STATE_TRKPT_TIME
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

				when "ele"
					if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT
						state = STATE_TRKPT_ELE
					else
						state = STATE_TRKPT
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
					end
				end
			end

			tour.set_start_end

			tour
		end

		def self.write_routes(output_file, tour)
			File.open(output_file, "w:utf-8") do |file|
			file << <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
EOF

				tour.routes.each do |pc|
					pc.path_list.each.with_index do |route, i|
						file << <<EOF
	<wpt lat="#{route.steps[0].lat}" lon="#{route.steps[0].lon}">
		<ele>#{route.steps[0].ele}</ele>
		<name>PC#{pc.index} - ★#{i + 1}</name>
	</wpt>
EOF
					end
				end

				file << <<EOF
	<wpt lat="#{tour.routes[-1].path_list[-1].steps[-1].lat}" lon="#{tour.routes[-1].path_list[-1].steps[-1].lon}">
		<ele>#{tour.routes[-1].path_list[-1].steps[-1].ele}</ele>
		<name>PC#{tour.routes[-1].index} - ★#{tour.routes[-1].path_list.size + 1}</name>
	</wpt>
EOF

				file << <<EOF
	<trk>
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
	end
end

