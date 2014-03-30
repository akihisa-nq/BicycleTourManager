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
end
