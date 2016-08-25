require "bicycle_tour_manager"

include BTM

require "rgeo"

describe Path do
	ele_cache = PStoreCache.new("test_cache_elevation.db")

	it "uses geos library" do
		expect(RGeo::Geos.supported?).to eq true
	end

	it "can be fetch elevation" do
		path = Path.new
		path.steps << Point.new(34.9789209478, 135.7896461897)
		path.steps << Point.new(34.9799845275, 135.7883505989)
		path.fetch_elevation(ele_cache)
		expect(path.steps[0].ele).to be > 0.0
		expect(path.steps[1].ele).to be > 0.0
	end

	it "check peak" do
		path = Path.new
		path.steps << Point.new(34.9789209478, 135.7896461897, 10.0)
		path.steps << Point.new(34.9789209478, 135.7896461897, 5.0)
		path.steps << Point.new(34.9799845275, 135.7883505989, 20.0)
		path.steps << Point.new(34.9799845275, 135.7883505989, 28.0)
		path.steps << Point.new(34.9799845275, 135.7883505989, 25.0)

		Path.check_peak(path.steps)

		expect(path.steps[0].min_max).to eq :mark_max
		expect(path.steps[0].next_peak.ele).to eq path.steps[1].ele

		expect(path.steps[1].min_max).to eq :mark_min
		expect(path.steps[1].next_peak.ele).to eq path.steps[3].ele

		expect(path.steps[2].min_max).to eq nil
		expect(path.steps[2].next_peak).to eq nil

		expect(path.steps[3].min_max).to eq :mark_max
		expect(path.steps[3].next_peak.ele).to eq path.steps[4].ele

		expect(path.steps[4].min_max).to eq :mark_min
		expect(path.steps[4].next_peak).to eq nil
	end

	it "check peak monotonic increse" do
		path = Path.new
		path.steps << Point.new(34.9789209478, 135.7896461897, 4.0)
		path.steps << Point.new(34.9789209478, 135.7896461897, 5.0)
		path.steps << Point.new(34.9799845275, 135.7883505989, 20.0)
		path.steps << Point.new(34.9799845275, 135.7883505989, 28.0)
		path.steps << Point.new(34.9799845275, 135.7883505989, 29.0)

		Path.check_peak(path.steps)

		expect(path.steps[0].min_max).to eq :mark_min
		expect(path.steps[0].next_peak.ele).to eq path.steps[4].ele
		expect(path.steps[1].min_max).to eq nil
		expect(path.steps[2].min_max).to eq nil
		expect(path.steps[3].min_max).to eq nil
		expect(path.steps[4].min_max).to eq :mark_max
	end

	it "check peak monotonic decrese" do
		path = Path.new
		path.steps << Point.new(34.9799845275, 135.7883505989, 29.0)
		path.steps << Point.new(34.9799845275, 135.7883505989, 28.0)
		path.steps << Point.new(34.9799845275, 135.7883505989, 20.0)
		path.steps << Point.new(34.9789209478, 135.7896461897, 5.0)
		path.steps << Point.new(34.9789209478, 135.7896461897, 4.0)

		Path.check_peak(path.steps)

		expect(path.steps[0].min_max).to eq :mark_max
		expect(path.steps[0].next_peak.ele).to eq path.steps[4].ele
		expect(path.steps[1].min_max).to eq nil
		expect(path.steps[2].min_max).to eq nil
		expect(path.steps[3].min_max).to eq nil
		expect(path.steps[4].min_max).to eq :mark_min
	end

	it "check gradient monotonic increse" do
		path = Path.new
		path.steps << Point.new(34.9789209478, 135.7896461897, 4.0)
		path.steps << Point.new(34.9789209478, 135.7896461897, 5.0)
		path.steps << Point.new(34.9799845275, 135.7883505989, 20.0)
		path.steps << Point.new(34.9799845275, 135.7883505989, 28.0)
		path.steps << Point.new(34.9799845275, 135.7883505989, 29.0)
		Path.check_peak(path.steps)
		grad = Path.check_gradient(path.steps)
	end

	# it "check peak with big data" do
	# 	path = File.join(File.dirname(__FILE__), "track_3.gpx")
	# 	tour = GpxStream.read(path)
	# 	tour.routes.each do |r|
	# 		r.path_list.each do |p|
	# 			Path.check_peak(p.steps)
	# 		end
	# 	end
	# end
end
