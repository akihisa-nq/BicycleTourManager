require "bicycle_tour_manager"

include BTM

describe Path do
	ele_cache = "test_cache_elevation.db"

	it "can be fetch elevation" do
		path = Path.new
		path.steps << Point.new(34.9789209478, 135.7896461897)
		path.steps << Point.new(34.9799845275, 135.7883505989)
		path.fetch_elevation(ele_cache)
		expect(path.steps[0].ele).to be > 0.0
		expect(path.steps[1].ele).to be > 0.0
	end
end
