# coding: utf-8

module BTM
	class PlanStream
		def self.read(input_file)
			plan = Tour.new
			plan.start_date = Time.new(2000, 1, 1, 0, 0, 0, 0)
			plan.routes << Route.new
			plan.routes.last.index = 1
			plan.routes.last.path_list << Path.new

			current = Point.new(0.0, 0.0)
			current.info = NodeInfo.new
			limit_speed = 15.0
			target_speed = 15.0
			total_distance = 0.0
			need_add = false

			File.open( input_file, "r:utf-8" ) do |file|
				file.each_line do |line|
					line[0] = "" if line[0] == "\uFEFF"

					case line
					when /^-- START:([\d\.]+) --/
						plan.start_date = parse_time($1)

					when /^-- SCHEDULE:([^ ]+)\s+([\d\.]+|START)\s+([\d\.]+)\s+([^ ]+)\s+(\d+) --/
						name = $1
						start_time = $2
						interval = ($3.to_f * 3600).to_i
						res = $4
						amount = $5.to_i

						if start_time == "START"
							start_time = plan.start_date
						else
							start_time = parse_time(start_time)
						end

						plan.schedule.push(Schedule.new(name, start_time, interval, res, amount))

					when /^\[([^\]]*)\]/
						$1.split(",").each do |s|
							case s.downcase
							when "hide"
								current.info.hide = true
							when "pass"
								current.info.pass = true
							end
						end

					when /^-- RESOURCE:([^ ]+)\s+(\d+)\s+([\d\.]+)\s(\d+) --/
						name = $1
						amount = $2.to_i
						interval = ($3.to_f * 3600).to_i
						buffer = $4.to_i
						plan.resources.push(Resource.new(name, amount, interval, buffer))

					when /^-- PC(\d+) --/
						plan.routes << Route.new
						plan.routes.last.index = $1.to_i + 1
						plan.routes.last.path_list << Path.new

					when /^--\s*$/
						plan.routes.last.path_list.last.steps.last.info.page_break = true
						plan.routes.last.path_list << Path.new

					when /^-- LIMIT:([\d\.]+) --/
						current.info.limit_speed = $1.to_f
						limit_speed = current.info.limit_speed

					when /^-- TARGET:([\d\.]+) --/
						current.info.target_speed = $1.to_f
						target_speed = current.info.target_speed

					when /^\+([\d\.]+(km|h))/
						if $2 == "km"
							total_distance += $1.to_f
						else
							current.info.rest_time = $1.to_f
						end

						current.distance_from_start = total_distance
						need_add = true

					when /^\s+$/
						if need_add
							plan.routes.last.path_list.last.steps << current
							need_add = false
						end

						current = Point.new(0.0, 0.0)
						current.info = NodeInfo.new
						current.info.limit_speed = limit_speed
						current.info.target_speed = target_speed

					else
						if current.info.parse_direction(line)
							unless current.info.valid_direction?
								$stderr << "間違った方向が PC#{plan.routes.count} のページ #{plan.routes.last.path_list.count}、#{plan.routes.last.path_list.last.steps.count} #{current.name} にあります。\n"
								exit 1
							end
						else
							current.info.text += line
						end
					end
				end

				if need_add
					plan.routes.last.path_list.last.steps << current
				end

				plan.routes.delete_at(-1) if plan.routes.last.path_list.length == 1 && plan.routes.last.path_list.last.steps.length == 0
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

		private

		def self.parse_time(str)
			/(\d+)\.(\d+)/ =~ str
			Time.new(2000, 1, 1, $1.to_i, $2.to_i * 60 / 100, 0, 0)			
		end
	end
end
