require "bicycle_tour_manager"

include BTM

describe AltitudePloter do
	it "plots for empty tour" do
		tour = Tour.new

		plotter = BTM::AltitudePloter.new(ENV["GNUPLOT"], File.dirname(__FILE__))
		plotter.elevation_max = 1100
		plotter.elevation_min = -100
		plotter.distance_max = 10.0

		path = File.join(File.dirname(__FILE__), "test.png")
		plotter.plot(tour, path)
		expect(File.exist?(path)).to eq true
	end

	it "can plot graph when not succeeding" do
		tour = Tour.new
		tour.routes << Route.new
		tour.routes.last.path_list << Path.new

		tour.routes.last.path_list.last.steps << Point.new(34.0, 135.0, 0.0)
		tour.routes.last.path_list.last.steps << Point.new(34.0, 136.0, 100.0)
		tour.routes.last.path_list.last.steps << Point.new(34.0, 136.0, 200.0)
		tour.routes.last.path_list.last.steps << Point.new(34.0, 138.0, 0.0)

		plotter = BTM::AltitudePloter.new(ENV["GNUPLOT"], File.dirname(__FILE__))
		plotter.elevation_max = 1100
		plotter.elevation_min = -100
		plotter.distance_max = 10.0

		path = File.join(File.dirname(__FILE__), "test.png")
		plotter.plot(tour, path)
		expect(File.exist?(path)).to eq true
	end

	it "plots a gpx" do
		gpx = File.join(File.dirname(__FILE__), "route.gpx")
		tour = GpxStream.read(gpx)

		plotter = BTM::AltitudePloter.new(ENV["GNUPLOT"], File.dirname(__FILE__))
		plotter.elevation_max = 1100
		plotter.elevation_min = -100
		plotter.distance_max = 10.0

		path = File.join(File.dirname(__FILE__), "test.png")
		plotter.plot(tour, path)
		expect(File.exist?(path)).to eq true
	end
end
