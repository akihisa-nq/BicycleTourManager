# coding: utf-8

require "open3"

module BTM
	class AltitudePloter
		PEAK_LIMIT_DISTANCE = 0.5
		PEAK_LIMIT_GRADIENT = 3.0
		PEAK_LIMIT_DISTANCE_LONG = 5.0
		PEAK_LIMIT_GRADIENT_LONG = 2.0

		GRAD_LIMIT_SPLIT_ELEVATION = 37.5
		GRAD_LIMIT_GRADIENT = PEAK_LIMIT_GRADIENT.to_i
		GRAD_LIMIT_DISTANCE_LONG = 5.0
		GRAD_LIMIT_GRADIENT_LONG = 2.0

		def initialize(gnuplot, tmpdir)
			@gnuplot = gnuplot
			@tmpdir = tmpdir
			@font = nil
			@elevation_max = 1100
			@elevation_min = -100
			@distance_max = 120
			@scale = 1.0
		end

		def plot(route, outfile)
			tmp_files = * %w{graph waypoint peak grad grad_label}.map do |i|
					File.join(@tmpdir, i + ".data")
				end
			graph_data, waypoint_data, peak_data, gradient_data, gradient_label_data = *tmp_files

			# フラット化
			tmp = route.flatten

			# ピークをマーク
			Path.check_peak(tmp)

			# 傾斜を計算
			grads = check_gradient(tmp)

			File.open(graph_data, "w") do |graph|
			File.open(waypoint_data, "w") do |waypoint|
			File.open(peak_data, "w") do |peak|
				# データ ファイルを出力
				prev_waypoint = nil
				prev_peak = nil

				tmp.each.with_index do |pt, i|
					graph << "#{pt.distance_from_start} #{pt.ele}\n"

					if pt.waypoint?
						if prev_waypoint.nil? \
						  || pt.distance_from_start - prev_waypoint.distance_from_start >= 2.5 \
						  || (pt.ele - prev_waypoint.ele).abs >= 100.0
						then
							waypoint << "#{pt.distance_from_start} #{pt.ele} ★#{pt.waypoint_index}\\n\n"
							prev_waypoint = pt
						end
					end

					if pt.min_max_marked?
						if pt.min_max == :mark_max
							diff_dis = pt.distance_from_start - prev_peak.distance_from_start
							diff_ele = pt.ele - prev_peak.ele
							grad_val = diff_ele / diff_dis / 10.0

							if diff_dis >= PEAK_LIMIT_DISTANCE && grad_val >= PEAK_LIMIT_GRADIENT \
								|| (grad_val >= PEAK_LIMIT_GRADIENT_LONG && diff_dis >= PEAK_LIMIT_DISTANCE_LONG)
							then
								peak << "#{pt.distance_from_start} #{pt.ele} #{pt.ele.to_i}\n"
							end
						end

						prev_peak = pt
					end
				end
			end; end; end

			File.open(gradient_data, "w") do |grad|
			File.open(gradient_label_data, "w") do |grad_label|
				grads.each do |e|
					diff_dis = e[:end].distance_from_start - e[:start].distance_from_start

					if e[:grad] >= GRAD_LIMIT_GRADIENT \
						|| (e[:grad] >= GRAD_LIMIT_GRADIENT_LONG && diff_dis >= GRAD_LIMIT_DISTANCE_LONG)
					then
						grad << "#{e[:start].distance_from_start} #{e[:start].ele} -50 #{e[:start].distance_from_start.round}\\n+#{diff_dis.round}\n"
						grad << "#{e[:end].distance_from_start} #{e[:end].ele}\n"
						grad << "\n"

						dis = (e[:start].distance_from_start + e[:end].distance_from_start) / 2
						ele = (e[:start].ele + e[:end].ele) / 2
						grad_label << "#{dis} #{ele} #{e[:grad]}%\n"
					end
				end
			end; end

			Open3.popen3( "\"#{@gnuplot}\" -persist" ) do |pipe, unused1, unused2, thread|
				unused1.close
				unused2.close

				base_dis = 120
				base_ele = 1200
				image_base_x = 1200
				image_base_y = 300

				max_dis = @distance_max
				max_ele = @elevation_max
				min_ele = @elevation_min
				ele_range = max_ele - min_ele

				image_x = (image_base_x.to_f * max_dis.to_f / base_dis.to_f * @scale).to_i
				image_y = (image_base_y.to_f * ele_range.to_f / base_ele.to_f * @scale).to_i

				pipe << "unset key\n"
				pipe << "set grid xtics mxtics ytics\n"
				pipe << "set xtics 5\n"
				pipe << "set ytics 100\n"
				pipe << "set mxtics 2\n"
				pipe << "set mytics 2\n"
				pipe << "show mxtics\n"
				pipe << "show mytics\n"
				pipe << "set xrange [0:#{max_dis}]\n"
				pipe << "set yrange [#{min_ele}:#{max_ele}]\n"
				pipe << "set xlabel 'distance, km'\n"
				pipe << "set ylabel 'elevation, m'\n"
				pipe << "set terminal png size #{image_x},#{image_y}\n"

				if @font
					pipe << "set terminal png font '#{@font}'\n"
				end

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

			tmp_files.each {|f| File.delete(f) }
		end

		attr_accessor :elevation_max, :elevation_min, :distance_max, :scale, :font

		private

		def check_gradient(tmp)
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

				break [{
					:start => tmp[i],
					:end => tmp[j],
					:grad => (a / 10.0).to_i
				}]
			end

			prev = 0
			tmp.each.with_index do |e, i|
				unless e.min_max.nil?
					if e.min_max == :mark_max
						ret = calc.call(prev, i)
						next if ret.size == 0

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
	end
end
