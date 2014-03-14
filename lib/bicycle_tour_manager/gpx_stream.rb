# coding: utf-8

module BTM
	class GpxStream
		def self.write_routes(output_file, routes)
			File.open(output_file, "w:utf-8") do |file|
			file << <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
EOF

				routes.each do |pc|
					pc.path_list.each.with_index do |route, i|
						file << <<EOF
	<wpt lat="#{route.steps[0][:lat]}" lon="#{route.steps[0][:lon]}">
		<ele>#{route.steps[0][:ele]}</ele>
		<name>PC#{pc.index} - ★#{i + 1}</name>
	</wpt>
EOF
					end
				end

				file << <<EOF
	<wpt lat="#{routes[-1].path_list[-1].steps[-1][:lat]}" lon="#{routes[-1].path_list[-1].steps[-1][:lon]}">
		<ele>#{routes[-1].path_list[-1].steps[-1][:ele]}</ele>
		<name>PC#{routes[-1].index} - ★#{routes[-1].path_list.size + 1}</name>
	</wpt>
EOF

				file << <<EOF
	<trk>
EOF

				routes.each do |pc|
					file << <<EOF
		<trkseg>
EOF

				pc.path_list.each do |route|
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
	end
end

