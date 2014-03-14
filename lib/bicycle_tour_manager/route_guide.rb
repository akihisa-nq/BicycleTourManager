# coding: utf-8

module BTM
	class RouteGuide
		def self.create_template(output_file, routes)
			count = 1

			File.open(output_file, "w:utf-8") do |file|
				file << <<EOF
スタート
+0.01h

EOF

				routes.each do |pc|
					pc.path_list.each.with_index do |route, j|
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

-- PC#{pc.index} --

EOF
				end
			end
		end
	end
end
