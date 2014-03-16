# coding: utf-8

require "spec_helper"

require "bicycle_tour_manager"

include BTM

describe GpxStream do
	it "can read name and dates form gpx file" do
		file = File.join(File.dirname(__FILE__), "track.gpx")
		tour = GpxStream.read(file)
		expect(tour.name).to eq "シクロ ジャンブル"
		expect(tour.start_date).to eq Time.parse("2013-05-20T03:40:54Z")
		expect(tour.original_file_path).to eq file
	end

	it "can read steps form gpx file" do
		file = File.join(File.dirname(__FILE__), "track.gpx")
		tour = GpxStream.read(file)

		expect(tour.routes.length).to eq 2

		expect(tour.routes[0].path_list.last.steps[0].lat).to eq 34.9789209478
		expect(tour.routes[0].path_list.last.steps[0].lon).to eq 135.7896461897
		expect(tour.routes[0].path_list.last.steps[0].ele).to eq 137.13
		expect(tour.routes[0].path_list.last.steps[0].time).to eq Time.parse("2013-05-18T23:59:00Z")

		expect(tour.routes[0].path_list.last.steps[-1].lat).to eq 34.7786008380
		expect(tour.routes[0].path_list.last.steps[-1].lon).to eq 135.4869989678
		expect(tour.routes[0].path_list.last.steps[-1].ele).to eq 38.59
		expect(tour.routes[0].path_list.last.steps[-1].time).to eq Time.parse("2013-05-19T02:17:44Z")
	end

	it "can read start/end point form gpx file" do
		file = File.join(File.dirname(__FILE__), "track.gpx")
		tour = GpxStream.read(file)

		expect(tour.routes[0].path_list.last.start.lat).to eq 34.9789209478
		expect(tour.routes[0].path_list.last.start.lon).to eq 135.7896461897
		expect(tour.routes[0].path_list.last.start.ele).to eq 137.13
		expect(tour.routes[0].path_list.last.start.time).to eq Time.parse("2013-05-18T23:59:00Z")

		expect(tour.routes[0].path_list.last.end.lat).to eq 34.7786008380
		expect(tour.routes[0].path_list.last.end.lon).to eq 135.4869989678
		expect(tour.routes[0].path_list.last.end.ele).to eq 38.59
		expect(tour.routes[0].path_list.last.end.time).to eq Time.parse("2013-05-19T02:17:44Z")
	end

	it "sets distance for each path after reading gpx file" do
		file = File.join(File.dirname(__FILE__), "track.gpx")
		tour = GpxStream.read(file)

		expect(tour.routes[0].path_list.last.distance).to be > 0.0
		expect(tour.routes[1].path_list.last.distance).to be > 0.0
	end

	it "can be read and write gpx file" do
		file = File.join(File.dirname(__FILE__), "track.gpx")
		tour = GpxStream.read(file)

		file = File.join(File.dirname(__FILE__), "track_new.gpx")
		GpxStream.write_routes(file, tour)

		tour2 = GpxStream.read(file)
		expect(tour2.name).to eq "シクロ ジャンブル"
		expect(tour2.start_date).to eq Time.parse("2013-05-20T03:40:54Z")
	end
end
