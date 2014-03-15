require "bicycle_tour_manager"

include BTM

describe Tour do
	it "can be flatten" do
		tour = GpxStream.read(File.join(File.dirname(__FILE__), "track_2.gpx"))
		flat = tour.flatten
		expect(flat[0].lat).to eq 34.9762334581
		expect(flat[0].lon).to eq 135.7956534997
		expect(flat[-1].lat).to eq 34.3722180929
		expect(flat[-1].lon).to eq 135.7883035764
	end
end
