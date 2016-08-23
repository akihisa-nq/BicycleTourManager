# coding: utf-8

module BTM
	class PlanContext
		def initialize(plan, plotter, work_dir, option)
			@plan = plan
			@plotter = plotter
			@work_dir = work_dir

			@node = Point.new(0.0, 0.0)
			@node.info = NodeInfo.new
			@pc = PlanRouteContext.new(@node)

			@node.time = plan.start_date
			@node.time_target = plan.start_date

			@node_base = @node

			@distance_addition = 0.0
			@time_addtion = 0.0
			@target_time_addtion = 0.0

			@previous_total_target_time = plan.start_date
			@task_queue = []
			@res_context = plan.resources.map {|r| ResourceContext.new(r) }
			@schedule_context = plan.schedule.map {|s| ScheduleContext.new(s) }

			@per_page = option[:per_page] || 3
			@enable_hide = option[:enable_hide].nil? ? true : option[:enable_hide]
			@format = option[:format] || :standard
		end

		def update_resource_status(&block)
			false unless @route.path_list.length - 1 == @page_number

			@res_context.each do |res|
				res.update(@node.time_target)
			end

			@schedule_context.each do |sch|
				sch.update(@previous_total_target_time, @node.time_target)
				if sch.fired?
					@task_queue.push(Task.new(sch.schedule))

					res = @res_context.find do |r|
							r.resource.name == sch.schedule.resource
						end

					res.buffer -= sch.schedule.amount
				end
 			end

			@use = {}

			res = @res_context.select{|r| r.usable? }.map{|r| r.dup}
			while true
				res_use = nil
				task = @task_queue.find { |t| res_use = res.find {|r| r.resource.name == t.resource} }
				break unless task

				if task.amount > res_use.amount
					task.amount -= res_use.amount
					res.delete(res_use)

					@use[task.resource] ||= 0
					@use[task.resource] += res_use.amount
				else
					res_use.amount -= task.amount
					res.delete(res_use) if res_use.amount == 0
					@task_queue.delete(task)

					@use[task.resource] ||= 0
					@use[task.resource] += task.amount
				end
			end

			@use.each do |key, value|
				check = @res_context.find {|r| r.usable? && r.resource.name == key }
				check.reserve(@node.time_target, value) if check
			end

			block.call

			@previous_total_target_time = @node.time_target
		end

		def pc_total_distance
			@pc.total_distance(@node)
		end

		def each_page(&block)
			@generated = {}

			@plan.routes.each do |route|
				@route = route
				@pc.reset(@node)
				page_max = 0
				@page_number = 0

				plot_graph()

				count = 1
				@route.path_list.each do |page|
					count += 1

					if page.end.info.page_break? || count >= @per_page
						count = 0
						page_max += 1
					end
				end
				page_max += 1

				@page_node = [ @route.path_list.first.start ]
				@route.path_list.each do |page|
					@page_node << page.end

					if page.end.info.page_break? || @page_node.length >= @per_page
						block.call(@route, @page_number, page_max)

						@page_node.clear
						@page_number += 1
					end
				end

				if @page_node.length > 0
					block.call(@route, @page_number, page_max)
					@page_node.clear
				end
			end
		end

		def each_node(&block)
			@page_node.each do |node|
				increment(node)
				block.call(node)
			end
		end

		def enable_hide?
			@enable_hide
		end

		def route_count
			@plan.routes.count
		end

		attr_reader :distance_addition, :time_addition, :target_time_addition, :pc, :route, :node, :task_queue, :res_context, :schedule_context, :use, :page_number

		private

		def plot_graph
			if @plotter
				unless @generated[@route.index]
					min, max = *@route.elevation_minmax
					min ||= 0
					max ||= 1000

					@plotter.elevation_min = (min / 100) * 100 - 100
					@plotter.elevation_max = [@plotter.elevation_min + 1100, ((max - 1) / 100 + 1) * 100].max + 100
					@plotter.distance_offset = @route.path_list[0].steps[0].distance_from_start
					@plotter.waypoint_offset = 0

					path = File.join(@work_dir, "PC#{@route.index}.png")
					@plotter.plot(@route, path)

					@generated[@route.index] = true
				end
			end
		end

		def increment(node)
			@distance_addition = node.distance_on_path(@node_base)

			@time_addition = (@distance_addition / @node_base.info.limit_speed * 3600).to_i
			@target_time_addition = ((@distance_addition / @node_base.info.target_speed + node.info.rest_time) * 3600).to_i

			node.time = @node_base.time + @time_addition
			node.time_target = @node_base.time_target + @target_time_addition

			@pc.increment(@time_addition, @target_time_addition)

			@node = node
			if node.info && ! node.info.pass
				@node_base = node
			end
		end
	end

	class PlanRouteContext
		def initialize(node)
			reset(node)
		end

		def reset(node)
			@start = node
			@total_time = Time.new(2000, 1, 1, 0, 0, 0, 0)
			@total_target_time = Time.new(2000, 1, 1, 0, 0, 0, 0)
		end

		def increment(elapsed_time, target_elapsed_time)
			@total_time += elapsed_time
			@total_target_time += target_elapsed_time
		end

		def total_distance(node)
			node.distance_on_path(@start)
		end

		attr_accessor :total_time, :total_target_time
	end

	class ResourceContext
		def initialize(res)
			@resource = res

			@start = nil
			@using = 0
			@status = ""

			@buffer = res.buffer
			@amount = res.amount
		end

		def usable?
			@start.nil?
		end

		def update(now)
			ret = false

			if @start && @start + @resource.interval <= now
				@start = nil
				@buffer += @using
				ret = true
			end

			if ret
				@status = "完了"
			elsif not usable?
				@status = "使用中"
			else
				@status = ""
			end
		end

		def reserve(now, amount)
			@start = now
			@using = amount
		end

		attr_reader :resource, :status
		attr_accessor :buffer, :amount
	end

	class ScheduleContext
		def initialize(sch)
			@schedule = sch
			@fired = false
		end

		def update(prev, now)
			@fired = @schedule.fire?( prev, now )
		end

		def fired?
			@fired
		end

		attr_reader :schedule
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
end


