# coding: utf-8

class ControlPoint
	def initialize num
		@num = num
		@pages = []
		@pages << Page.new
	end

	attr_reader :num, :pages
end

class Page
	def initialize
		@nodes = []
	end

	attr_reader :nodes
end

class Node
	def initialize( src_line )
		@text = ""
		@name = ""
		@road = {}
		@limit_speed = 15.0
		@target_speed = 15.0
		@src_line = src_line
		@distance = 0.0
		@rest_time = 0.0
	end

	def road_html
		out = ""

		out << <<EOF
<div style="position:relative; float : left; width : 64px; height : 64px;">
EOF
	
		image_root = "file:///" + File.dirname(__FILE__).gsub("\\", "/")

		@road.keys.each do |i|
			out << <<EOF
<img src="#{image_root}/images/normal_#{i.downcase}.png" style="position:absolute; left:0px; top:0px;"/>
EOF
		end

		unless @orig.nil?
			out << <<EOF
<img src="#{image_root}/images/orig_#{@orig.downcase}.png" style="position:absolute; left:0px; top:0px;"/>
EOF
		end

		unless @dest.nil?
			out << <<EOF
<img src="#{image_root}/images/dest_#{@dest.downcase}.png" style="position:absolute; left:0px; top:0px;"/>
EOF
		end

		out << <<EOF
</div>
EOF

		out
	end

	def next_road
		@dest.nil? ? "" : @road[@dest]
	end

	def other_roads
		return "" if @orig.nil?

		@road
			.to_a
			.sort_by{|i| dir_id(i[0]) }
			.select{|v| v[0] != @orig && v[0] != @dest }
			.map { |v| relative_dir(@orig, v[0]) + " " + v[1] }
			.join(", ")
	end

	def next_relative_dir
		unless @dest.nil? && @orig.nil?
			relative_dir(@orig, @dest)
		else
			""
		end 
	end

	def dir_id(name)
		case name
		when "N"
			0
		when "NE"
			1
		when "E"
			2
		when "SE"
			3
		when "S"
			4
		when "SW"
			5
		when "W"
			6
		when "NW"
			7
		end
	end

	def relative_dir( o, d )
		diff = dir_id(d) - dir_id(o)
		diff += 8 if diff < 0

		case diff
		when 0
			"後ろ"
		when 1
			"左後"
		when 2
			"左折"
		when 3
			"左前"
		when 4
			"直進"
		when 5
			"右前"
		when 6
			"右折"
		when 7
			"右後"
		end
	end

	def elapsed_time
		@distance / @limit_speed
	end

	def target_elapsed_time
		@distance / @target_speed + @rest_time
	end

	def valid?
		@distance > 0 || @rest_time > 0
	end

	attr_accessor :text, :name, :road, :orig, :dest, :distance, :src_line, :limit_speed, :target_speed, :rest_time
end

class Schedule
	def initialize( name, start_time, interval, res, amount )
		@name = name
		@start_time = start_time
		@interval = interval
		@resource = res
		@amount = amount
	end

	def fire?(prev, now)
		n = ((now - start_time) / interval).to_i
		return false if n <= 0

		cur = start_time + n * interval
		return prev < cur && cur <= now
	end

	attr_reader :name, :start_time, :interval, :resource, :amount
end

class Task
	def initialize( schedule )
		@name = schedule.name
		@amount = schedule.amount
		@resource = schedule.resource
	end

	attr_reader :name, :resource
	attr_accessor :amount
end

class Resource
	def initialize( name, amount, recovery_interval, buffer )
		@name = name
		@amount = amount
		@interval = recovery_interval
		@start = nil
		@buffer = buffer
		@using = 0
	end

	def usable?
		@start.nil?
	end

	def check(now)
		ret = false

		if @start && @start + interval <= now
			@start = nil
			@buffer += @using
			ret = true
		end

		ret
	end

	def reserve(now, amount)
		@start = now
		@using = amount
	end

	attr_reader :name, :interval
	attr_accessor :amount, :buffer
end

def filter text
	text
		.gsub(/(.(分岐路|岐路|字路))/) { %Q+<span style="font-weight:bold">#{$1}</span>+ }
		.gsub(/(左折|右折|直進)/) { %Q+<span style="font-weight:bold">#{$1}</span>+ }
		.gsub(/(([A-Z]+)?R[\d\/]+)/) { %Q+<span style="font-weight:bold">#{$1}</span>+ }
end

# ここから
$start_time = 0.0
$schedule = []
$task_queue = []
$resources = []
cource = [ ControlPoint.new(1) ]

INPUT_FILE = ARGV.shift
INPUT_DIR = File.dirname(INPUT_FILE)

File.open( INPUT_FILE, "r:utf-8" ) do |file|
	current = Node.new(1)
	limit_speed = 15.0
	target_speed = 15.0

	file.each_line.with_index do |line, i|
		line[0] = "" if line[0] == "\uFEFF"

		case line
		when /^-- START:([\d\.]+) --/
			$start_time = $1.to_f
		when /^-- SCHEDULE:([^ ]+)\s+([\d\.]+|START)\s+([\d\.]+)\s+([^ ]+)\s+(\d+) --/
			$schedule.push(Schedule.new($1, $2 == "START" ? $start_time : $2.to_f, $3.to_f, $4, $5.to_i))
		when /^-- RESOURCE:([^ ]+)\s+(\d+)\s+([\d\.]+)\s(\d+) --/
			$resources.push(Resource.new($1, $2.to_i, $3.to_f, $4.to_i))
		when /^-- PC(\d+) --/
			cource << ControlPoint.new($1.to_i + 1)
		when /^--\s*$/
			cource.last.pages << Page.new
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
			cource.last.pages.last.nodes << current if current.valid?
			current = Node.new(i + 1)
			current.limit_speed = limit_speed
			current.target_speed = target_speed
		when /^\@(.*)\|(.*)\|(.*)$/
			road = $1
			dir = $2
			name = $3.strip

			current.road = Hash[*road.split(/[:,]/).map{|i| i.strip}]
			current.name = name

			if dir =~ /(.*)->(.*)/
				current.orig = $1.strip
				current.dest = $2.strip

				if current.road[current.orig].nil? || current.road[current.dest].nil?
					throw Exception.new("間違った方向が PC#{cource.count} のページ #{cource.last.pages.count}、#{cource.last.pages.last.nodes.count} #{current.name} にあります。")
				end
			end
		else
			current.text += line
		end
	end

	cource.last.pages.last.nodes << current if current.valid?
	cource.delete_at(-1) if cource.last.pages.length == 1 && cource.last.pages.last.nodes.length == 0
end

File.open( "#{INPUT_DIR}/result.html", "w:utf-8" ) do |file|
	file << <<EOF
<html>
	<head>
		<style>
		@page
		{
			
			size : 210mm 148mm;
		}

		h1
		{
			font-size : 8pt;
			text-align : center;
			margin-bottom : 0em;
		}

		table
		{
			width : 48%;
			border : 1px solid black;
			border-collapse : collapse;
			margin-bottom : 1%;
			float : left;
		}

		td
		{
			font-size : 8pt;
			padding : 0.1em;
			border : 1px solid black;
		}

		.page
		{
			clear : both;
			page-break-after : always;
			page-break-inside : avoid;
		}

		.page:last-child
		{
			page-break-after : auto;
		}

		.comment
		{
			clear : both;
			font-size : 6pt;
		}
		</style>
	</head>
	<body>
EOF

	total_distance = 0.0
	total_time = $start_time
	total_target_time = $start_time
	previous_total_target_time = $start_time

	cource.each do |pc|
		pc_total_distance = 0.0
		pc_total_time = 0.0
		pc_total_target_time = 0.0

		pc.pages.each.with_index do |page, i|
			file << <<EOF
<div class="page">
<h1>PC#{pc.num} #{i + 1}/#{pc.pages.length}</h1>
EOF

			if File.exist?("PC#{pc.num}.png")
				file << <<EOF
	<div style="text-align:center">
		<img src="file:///#{INPUT_DIR.gsub("\\", "/")}/PC#{pc.num}.png" style="width:100%" />
	</div>
EOF
			end

			page.nodes.each do |node|
				total_distance += node.distance
				pc_total_distance += node.distance

				format_time = lambda do |time|
					hour = time.to_i
					minute = ((time - hour.to_f) * 60).to_i
					hour %= 24
					"%02d:%02d" % [hour, minute]
				end

				total_time += node.elapsed_time
				pc_total_time += node.elapsed_time

				total_target_time += node.target_elapsed_time
				pc_total_target_time += node.target_elapsed_time

				file << <<EOF
	<!-- #{node.src_line} -->

	<table>
	<tr>
		<td style="font-weight : bold; width : 11ex;">#{"%.1f" % [pc_total_distance]} km</td>
		<td rowspan="3" style="width : 64px; height:64px;">#{node.road_html}</td>
		<td>#{node.name}</td>
		<td>#{node.next_relative_dir} #{node.next_road}</td>
		<td style="width : 11ex;">#{"%.1f" % [total_distance]} km</td>
	</tr>
	<tr>
EOF

		if node.distance > 0 then
				file << <<EOF
		<td style="width : 11ex;">+ #{"%.1f" % [node.distance]} km</td>
EOF
		else
				file << <<EOF
		<td style="width : 11ex;">+ #{"%02d:%02d" % [node.rest_time.to_i, (node.rest_time % 1.0) * 60]}</td>
EOF
		end

				file << <<EOF
		<td colspan="2" style="font-size:7pt">#{node.other_roads}</td>
		<td style="font-weight : bold; width : 11ex;">#{format_time.call(total_target_time)}/#{format_time.call(total_time)}</td>
	</tr>
	<tr>
		<td style="font-weight : bold; width : 11ex;">#{format_time.call(pc_total_target_time)}/#{format_time.call(pc_total_time)}</td>
		<td colspan="2" style="font-size:7pt">#{filter(node.text)}</td>
		<td style="width:11ex;"><span style="font-size:7pt;">速</span>#{node.target_speed}/#{node.limit_speed}</td>
	</tr>
	</table>
	<div style="float:left; font-size:3pt; width : 1%;">
		<br />
		<br />
		<br />
		＞<br />
		<br />
		<br />
		<br />
	</div>
EOF
			end

			if pc.pages.length - 1 == i
				# 定期タスクの処理
				file << <<EOF
			<div class="comment">
EOF

				$resources.each do |r|
					if r.check(total_target_time)
						file << <<EOF
					【#{r.name} 完了】
EOF
					elsif not r.usable?
						file << <<EOF
					【#{r.name} 使用中】
EOF
					end
				end

				$schedule.each do |sch|
					if sch.fire?( previous_total_target_time, total_target_time )
						$task_queue.push(Task.new(sch))
						$resources.find{|r| r.name == sch.resource}.buffer -= sch.amount
						file << <<EOF
					【#{sch.name}】
EOF
					end
				end

				use = {}

				res = $resources.select{|r| r.usable? }.map{|r| r.dup}
				while true
					res_use = nil
					task = $task_queue.find { |t| res_use = res.find {|r| r.name == t.resource} }
					break unless task

					if task.amount > res_use.amount
						task.amount -= res_use.amount
						res.delete(res_use)

						use[task.resource] ||= 0
						use[task.resource] += res_use.amount
					else
						res_use.amount -= task.amount
						res.delete(res_use) if res_use.amount == 0
						$task_queue.delete(task)

						use[task.resource] ||= 0
						use[task.resource] += task.amount
					end
				end

				use.each do |key, value|
					check = $resources.find {|r| r.usable? && r.name == key }
					check.reserve(total_target_time, value) if check

					file << <<EOF
					【#{key} #{value}】
EOF
				end

				$resources.each do |r|
					if r.buffer < 0
						throw Exception.new("#{r.name} が #{- r.buffer} 不足")
					end

					file << <<EOF
					- #{r.name} #{r.buffer}
EOF
				end

				file << <<EOF
			</div>
EOF

				previous_total_target_time = total_target_time
			end

			file << <<EOF
</div>
EOF
		end
	end

file << <<EOF
</body>
</html>
EOF
end

