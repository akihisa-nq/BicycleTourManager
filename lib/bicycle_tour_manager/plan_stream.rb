# coding: utf-8

module BTM
	class PlanStream
		def self.read(input_file)
			plan = Plan.new
			plan.routes << ControlPoint.new(1)

			current = Node.new(1)
			limit_speed = 15.0
			target_speed = 15.0

			File.open( input_file, "r:utf-8" ) do |file|
				file.each_line.with_index do |line, i|
					line[0] = "" if line[0] == "\uFEFF"

					case line
					when /^-- START:([\d\.]+) --/
						plan.start_time = $1.to_f

					when /^-- SCHEDULE:([^ ]+)\s+([\d\.]+|START)\s+([\d\.]+)\s+([^ ]+)\s+(\d+) --/
						plan.schedule.push(Schedule.new($1, $2 == "START" ? $start_time : $2.to_f, $3.to_f, $4, $5.to_i))

					when /^-- RESOURCE:([^ ]+)\s+(\d+)\s+([\d\.]+)\s(\d+) --/
						plan.resources.push(Resource.new($1, $2.to_i, $3.to_f, $4.to_i))

					when /^-- PC(\d+) --/
						plan.routes << ControlPoint.new($1.to_i + 1)

					when /^--\s*$/
						plan.routes.last.pages << Page.new

					when /^-- LIMIT:([\d\.]+) --/
						current.limit_speed = $1.to_f
						limit_speed = current.limit_speed

					when /^-- TARGET:([\d\.]+) --/
						current.target_speed = $1.to_f
						target_speed = current.target_speed

					when /^\+([\d\.]+(km|h))/
						if $2 == "km"
							current.distance = $1.to_f
						else
							current.rest_time = $1.to_f
						end

					when /^\s+$/
						plan.routes.last.pages.last.nodes << current if current.valid?
						current = Node.new(i + 1)
						current.limit_speed = limit_speed
						current.target_speed = target_speed

					else
						if current.parse_direction(line)
							unless current.valid_direction?
								$stderr << "間違った方向が PC#{plan.routes.count} のページ #{plan.routes.last.pages.count}、#{plan.routes.last.pages.last.nodes.count} #{current.name} にあります。\n"
								exit 1
							end
						else
							current.text += line
						end
					end
				end

				plan.routes.last.pages.last.nodes << current if current.valid?
				plan.routes.delete_at(-1) if plan.routes.last.pages.length == 1 && plan.routes.last.pages.last.nodes.length == 0
			end

			plan
		end

		def self.create_from_tour(output_file, tour)
			count = 1

			File.open(output_file, "w:utf-8") do |file|
				file << <<EOF
スタート
+0.01h

EOF

				tour.routes.each do |pc|
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
