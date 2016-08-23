# coding: utf-8

require "open3"

module BTM
	class AltitudePloter
		PEAK_LIMIT_DISTANCE = 0.5
		PEAK_LIMIT_GRADIENT = 3.0
		PEAK_LIMIT_DISTANCE_LONG = 5.0
		PEAK_LIMIT_GRADIENT_LONG = 2.0

		GRAD_LIMIT_GRADIENT = PEAK_LIMIT_GRADIENT.to_i
		GRAD_LIMIT_DISTANCE_LONG = 5.0
		GRAD_LIMIT_GRADIENT_LONG = 2.0

		def initialize(gnuplot, tmpdir)
			@gnuplot = gnuplot
			@tmpdir = tmpdir
			@font = nil
			@elevation_max = 1100
			@elevation_min = -100
			@distance_max = 150
			@scale = 1.0
			@label = true
			@distance_offset = 0.0
		end

		def plot(route, outfile)
			tmp_files = * %w{graph waypoint peak grad grad_label}.map do |i|
					File.join(@tmpdir, i + ".data")
				end
			graph_data, waypoint_data, peak_data, gradient_data, gradient_label_data = *tmp_files

			# フラット化
			tmp = route.flatten
			tmp.each do |s|
				s.distance_from_start += @distance_offset
			end

			# ピークをマーク
			Path.check_peak(tmp)

			# 傾斜を計算
			grads = Path.check_gradient(tmp)

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
							name = "★"
							if pt.route_index > 0
								name += "#{pt.route_index}-"
							end
							name += pt.waypoint_index.to_s

							waypoint << "#{pt.distance_from_start} #{pt.ele} #{name}\\n\n"
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
					diff_dis = e.end.distance_from_start - e.start.distance_from_start

					if e.grad >= GRAD_LIMIT_GRADIENT \
						|| (e.grad >= GRAD_LIMIT_GRADIENT_LONG && diff_dis >= GRAD_LIMIT_DISTANCE_LONG)
					then
						grad << "#{e.start.distance_from_start} #{e.start.ele} -50 #{e.start.distance_from_start.round}\\n+#{diff_dis.round}\n"
						grad << "#{e.end.distance_from_start} #{e.end.ele}\n"
						grad << "\n"

						dis = (e.start.distance_from_start + e.end.distance_from_start) / 2
						ele = (e.start.ele + e.end.ele) / 2
						grad_label << "#{dis} #{ele} #{e.grad}%\n"
					end
				end
			end; end

			Open3.popen3( "\"#{@gnuplot}\" -persist" ) do |pipe, unused1, unused2, thread|
				unused1.close
				unused2.close
				pipe << "set terminal png size 300,300 crop\n"
				if @font
					pipe << "set terminal png font '#{@font}'\n"
				end
				pipe << "set lmargin 0\n"
				pipe << "set rmargin 3\n"
				pipe << "set tmargin 3\n"
				pipe << "set bmargin 0\n"
				pipe << "set output '#{outfile}';\n"
				pipe << "plot x\n"
				pipe << "exit\n"
			end

			margin_unit = `identify -format "%w %h" #{outfile}`.split.map {|i| (300 - i.to_i) / 3 }
			File.delete(outfile)

			Open3.popen3( "\"#{@gnuplot}\" -persist" ) do |pipe, unused1, unused2, thread|
				unused1.close
				unused2.close

				base_dis = 120
				base_ele = 1200
				image_base_x = 1200
				image_base_y = 300

				min_dis = (@distance_offset / 2.5).to_i.to_f * 2.5
				max_dis = min_dis + @distance_max.to_f
				dis_range = @distance_max

				max_ele = @elevation_max
				min_ele = @elevation_min
				ele_range = max_ele - min_ele

				image_x = (image_base_x.to_f * dis_range.to_f / base_dis.to_f * @scale).to_i
				image_y = (image_base_y.to_f * ele_range.to_f / base_ele.to_f * @scale).to_i

				margins = {}
				if @label
					margins = @margins_with_label || {
						t: 1,
						b: 3,
						l: 10,
						r: 2,
					}
				else
					margins = @margins_without_label || {
						t: 1,
						b: 2,
						l: 6,
						r: 2,
					}
				end

				image_x += (margins[:l] + margins[:r]) * margin_unit[0]
				image_y += (margins[:t] + margins[:b]) * margin_unit[1]

				pipe << "unset key\n"
				pipe << "set grid xtics mxtics ytics\n"
				pipe << "set xtics 5\n"
				pipe << "set ytics 100\n"
				pipe << "set mxtics 2\n"
				pipe << "set mytics 2\n"
				pipe << "set xrange [#{min_dis}:#{max_dis}]\n"
				pipe << "set yrange [#{min_ele}:#{max_ele}]\n"

				margins.each do |key, value|
					pipe << "set #{key}margin #{value}\n"
				end
	
				if @label
					pipe << "set xlabel 'distance, km'\n"
					pipe << "set ylabel 'elevation, m'\n"
				end

				pipe << "set terminal png size #{image_x},#{image_y} nocrop\n"

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

		attr_accessor :elevation_max, :elevation_min, :distance_offset, :distance_max, :scale, :font, :label,
			:margins_with_label, :margins_without_label
	end
end

