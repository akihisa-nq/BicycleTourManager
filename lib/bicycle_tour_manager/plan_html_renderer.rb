# coding: utf-8

require "erb"

module BTM
	class PlanHtmlRenderer
		def initialize(plotter, option)
			@plotter = plotter
			@option = option
		end

		def render(plan, output)
			@plan = plan
			@output = output

			@context = PlanContext.new(@plan, @plotter, work_dir, option)

			File.open(output, "w:utf-8") do |output|
				File.open(File.join(File.dirname(__FILE__), "plan.html.erb"), "r:utf-8") do |file|
					output.write(
						ERB.new(file.read).result(binding)
						)
				end
			end
		end

		attr_reader :option

		private

		def work_dir
			File.dirname(@output)
		end

		def scaled(px)
			scale = @option[:scale] || 1.0
			"#{(scale * px).to_i}px"
		end

		def altitude_graph(index)
			pc_alt_image = File.absolute_path(File.join(work_dir, "PC#{index}.png"))

			if File.exist?(pc_alt_image)
				<<-EOS
<div class="altitude">
	<img src="file:///#{pc_alt_image.gsub("\\", "/")}" />
</div>
				EOS
			else
				""
			end
		end

		def pc_total_distance
			"%.1f" % [ @context.pc_total_distance ]
		end

		def total_distance
			"%.1f" % [ @context.node.distance_from_start ]
		end

		def pc_total_elapsed
			format_time(@context.pc.total_target_time) + "/" + format_time(@context.pc.total_time)
		end

		def total_elapsed_target
			format_time(@context.node.time_target)
		end

		def total_elapsed_limit
			format_time(@context.node.time)
		end

		def time_addition
			"%02d:%02d" % [ @context.time_addition / 3600, (@context.time_addition % 3600) / 60 ]
		end

		def target_time_addition
			"%02d:%02d" % [ @context.target_time_addition / 3600, (@context.target_time_addition % 3600) / 60 ]
		end

		def node_distance_addition
			if @context.distance_addition > 0.0
				"+%.1fk" % [ @context.distance_addition ]
			else
				""
			end
		end

		def node_time_addition
			if @context.node.info.rest_time > 0.0
				"(%02d:%02d 休み)" % [@context.node.info.rest_time.to_i, (@context.node.info.rest_time % 1.0) * 60]
			else
				""
			end
		end

		def comment
			filter(@context.node.info.text) + node_time_addition
		end

		def format_time(time)
			time.strftime("%H:%M")
		end

		def resource_status(res)
			if res.status.empty?
				""
			else
				"【#{res.resource.name} #{res.status}】"
			end
		end

		def schedule_status(sch)
			if sch.fired?
				"【#{sch.schedule.name}】"
			else
				""
			end
		end

		def resources_left(res)
			if res.buffer < 0
				"#{res.resource.name} が #{- res.buffer} 不足"
			else
				" - #{res.resource.name} #{res.buffer}"
			end
		end

		def render_node
			node = @context.node

			out = ""
	
			out << <<EOF
	<div class="direction_box">
EOF
	
			node.info.road.keys.each do |i|
				out << <<EOF
	<img src="#{image_root}/images/normal_#{i.downcase}.png" />
EOF
			end
	
			if ! node.info.orig.nil? && node.info.orig.downcase != "c"
				out << <<EOF
	<img src="#{image_root}/images/orig_#{node.info.orig.downcase}.png" />
EOF
			end
	
			if ! node.info.dest.nil? && node.info.dest.downcase != "c"
				out << <<EOF
	<img src="#{image_root}/images/dest_#{node.info.dest.downcase}.png" />
EOF
			end
	
			out << <<EOF
	</div>
EOF
	
			out
		end

		def image_root
			"file:///" + File.join(File.dirname(__FILE__), "../../data").gsub("\\", "/")
		end

		def filter text
			text
				.gsub(/(.(分岐路|岐路|字路))/) { %Q+<span class="alert">#{$1}</span>+ }
				.gsub(/(左折|右折|直進)/) { %Q+<span class="alert">#{$1}</span>+ }
				.gsub(/(([A-Z]+)?R[\d\/]+)/) { %Q+<span class="alert">#{$1}</span>+ }
		end
	end
end
