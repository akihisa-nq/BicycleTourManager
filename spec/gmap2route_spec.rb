# coding: utf-8

require "spec_helper"

describe "gmap2route" do
	it "can generate template, gpx and png files from googlemap url list file" do
		ENV["BICYCLE_TOUR_MANAGER_CACHE"] = File.dirname(__FILE__)

		test_file = File.join(File.dirname(__FILE__), "gmap.txt")
		bin = File.join(File.dirname(__FILE__), "../bin/gmap2route")

		result_files = %w{route_template.txt PC1.png PC2.png PC3.png route.gpx}.map do
			|e| File.join(File.dirname(__FILE__), e)
		end

		expect(system("ruby #{bin} #{test_file}")).to eq true

		result_files.each do |r|
			expect(File.exist?(r)).to eq true
		end
	end
end
