# coding: utf-8

module BTM
	class Plan
		def initialize
			@start_time = 0.0
			@routes = []
			@resources = []
			@schedule = []
		end

		attr_accessor :start_time
		attr_reader :routes, :resources, :schedule
	end

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

		def parse_direction(str)
			if /\@(.*)\|(.*)\|(.*)/ =~ str
				road = $1
				dir = $2
				name = $3.strip

				@road = Hash[*road.split(/[:,]/).map{|i| i.strip}]
				@name = name

				if dir =~ /(.*)->(.*)/
					@orig = $1.strip
					@dest = $2.strip
				end

				true
			else
				false
			end
		end

		def valid_direction?
			(@orig.nil? || ! @road[@orig].nil?) && (@dest.nil? || ! @road[@dest].nil?)
		end

		attr_accessor :text, :name, :road, :orig, :dest, :distance, :src_line, :limit_speed, :target_speed, :rest_time
	end

	class Schedule
		def initialize( name, start, interval, res, amount )
			@name = name
			@start_time = start
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
end

