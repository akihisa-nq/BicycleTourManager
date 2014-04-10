# coding: utf-8

require "erb"

module BTM
	class PlanHtmlRenderer
		def render(plan, output)
			task_queue = []

			File.open(output, "w:utf-8") do |output|
				File.open(File.join(File.dirname(__FILE__), "plan.html.erb"), "r:utf-8") do |file|
					output.write(
						ERB.new(file.read).result(binding)
						)
				end
			end
		end

		private

		def render_node(node)
			out = ""
	
			out << <<EOF
	<div style="position:relative; float : left; width : 64px; height : 64px;">
EOF
		
			image_root = "file:///" + File.join(File.dirname(__FILE__), "../data").gsub("\\", "/")
	
			node.road.keys.each do |i|
				out << <<EOF
	<img src="#{image_root}/images/normal_#{i.downcase}.png" style="position:absolute; left:0px; top:0px;"/>
EOF
			end
	
			unless node.orig.nil?
				out << <<EOF
	<img src="#{node.image_root}/images/orig_#{node.orig.downcase}.png" style="position:absolute; left:0px; top:0px;"/>
EOF
			end
	
			unless @dest.nil?
				out << <<EOF
	<img src="#{image_root}/images/dest_#{node.dest.downcase}.png" style="position:absolute; left:0px; top:0px;"/>
EOF
			end
	
			out << <<EOF
	</div>
EOF
	
			out
		end

		def filter text
			text
				.gsub(/(.(分岐路|岐路|字路))/) { %Q+<span style="font-weight:bold">#{$1}</span>+ }
				.gsub(/(左折|右折|直進)/) { %Q+<span style="font-weight:bold">#{$1}</span>+ }
				.gsub(/(([A-Z]+)?R[\d\/]+)/) { %Q+<span style="font-weight:bold">#{$1}</span>+ }
		end
	end
end
