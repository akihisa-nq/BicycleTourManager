# coding: utf-8

require "spec_helper"

require "bicycle_tour_manager"

include BTM

describe GpxStream do
	it "can read name and dates form gpx file" do
		tour = GpxStream.read(File.join(File.dirname(__FILE__), "track.gpx"))
		expect(tour.name).to eq "シクロ ジャンブル"
		expect(tour.start_date).to eq Time.parse("2013-05-20T03:40:54Z")
	end
end
