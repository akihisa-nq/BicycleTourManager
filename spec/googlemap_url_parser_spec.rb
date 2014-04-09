# coding: utf-8

require "spec_helper"

require "bicycle_tour_manager"

include BTM

describe GoogleMapUriParser do
	geocode_cache = PStoreCache.new("test_cache_geocode.db")
	route_cache = PStoreCache.new("test_cache_route.db")
	elevation_cache = PStoreCache.new("test_cache_elevation.db")
	uri = %Q|https://maps.google.co.jp/maps?saddr=%E5%9B%BD%E9%81%93370%E5%8F%B7%E7%B7%9A&daddr=34.1337228,135.4063698+to:%E5%9B%BD%E9%81%93370%E5%8F%B7%E7%B7%9A+to:%E5%9B%BD%E9%81%93480%E5%8F%B7%E7%B7%9A+to:%E6%8C%87%E5%AE%9A%E3%81%AE%E5%9C%B0%E7%82%B9&hl=ja&ie=UTF8&sll=34.18156,135.558243&sspn=0.131926,0.264187&geocode=FXhKCQIdayoQCA%3BFdrWCAIdISMSCCk3Y_DprjsHYDH_V-VlUgwqSg%3BFVrSCQIdGKMTCA%3BFRsMCgId66wUCA%3BFWgKCgIdg-UUCA&dirflg=w&brcurrent=3,0x6006d8c73c814c5d:0xdce24fdf8a7ba5d5,0&mra=mi&mrsp=3&sz=13&via=1&t=m&z=13|
	uri_new = %Q|https://www.google.co.jp/maps/dir/35.1156642,135.713829/35.1129261,135.7104386/35.1116974,135.7049884/@35.1210211,135.7066495,15z/am=t/data=!3m1!4b1!4m10!4m9!1m0!1m5!3m4!1m2!1d135.7001757!2d35.1236666!3s0x6001aef192cc015d:0xb71a1a272c111f30!1m0!3e2?hl=ja|
	uri_new2 = %Q|https://www.google.co.jp/maps/dir/35.1156642,135.713829/35.1129261,135.7104386/35.1139477,135.7058341/35.1116974,135.7049884/@35.1210211,135.7066495,15z/am=t/data=!3m1!4b1!4m16!4m15!1m0!1m5!3m4!1m2!1d135.7001757!2d35.1236666!3s0x6001aef192cc015d:0xb71a1a272c111f30!1m5!3m4!1m2!1d135.7049136!2d35.1133325!3s0x6001aedcc642ac1d:0xc62b7b6903ce7aa!1m0!3e2?hl=ja|

	it "can analyze old format without cache" do
		parser = GoogleMapUriParser.new(geocode_cache)
		File.delete(geocode_cache.path) if File.exist?(geocode_cache.path)
		expect(parser.parse_uri(uri)).not_to eq nil
	end

	it "can analyze old format with cache" do
		parser = GoogleMapUriParser.new(geocode_cache)
		File.delete(geocode_cache.path) if File.exist?(geocode_cache.path)
		expect(parser.parse_uri(uri)).not_to eq nil
		expect(parser.parse_uri(uri)).not_to eq nil
	end

	it "can analyze new format 1" do
		parser = GoogleMapUriParser.new(nil)
		route = parser.parse_uri(uri_new)
		expect(route).not_to eq nil
		expect(route.path_list.length).to eq 2
		
		expect(route.path_list[0].way_points.length).to eq 0
		expect(route.path_list[0].start.lat).to eq 35.1156642
		expect(route.path_list[0].start.lon).to eq 135.713829
		expect(route.path_list[0].end.lat).to eq 35.1129261 
		expect(route.path_list[0].end.lon).to eq 135.7104386

		expect(route.path_list[1].way_points.length).to eq 1
		expect(route.path_list[1].way_points[0].lat).to eq 35.1236666
		expect(route.path_list[1].way_points[0].lon).to eq 135.7001757

		expect(route.path_list[1].start.lat).to eq 35.1129261 
		expect(route.path_list[1].start.lon).to eq 135.7104386
		expect(route.path_list[1].end.lat).to eq 35.1116974
		expect(route.path_list[1].end.lon).to eq 135.7049884
	end

	it "can analyze new format 2" do
		parser = GoogleMapUriParser.new(nil)
		route = parser.parse_uri(uri_new2)
		expect(route).not_to eq nil
		expect(route.path_list.length).to eq 3
		
		expect(route.path_list[0].start.lat).to eq 35.1156642
		expect(route.path_list[0].start.lon).to eq 135.713829
		expect(route.path_list[0].end.lat).to eq 35.1129261 
		expect(route.path_list[0].end.lon).to eq 135.7104386

		expect(route.path_list[1].way_points.length).to eq 1
		expect(route.path_list[1].way_points[0].lat).to eq 35.1236666
		expect(route.path_list[1].way_points[0].lon).to eq 135.7001757

		expect(route.path_list[2].start.lat).to eq 35.1139477 
		expect(route.path_list[2].start.lon).to eq 135.7058341
		expect(route.path_list[2].end.lat).to eq 35.1116974
		expect(route.path_list[2].end.lon).to eq 135.7049884

		expect(route.path_list[2].way_points.length).to eq 1
		expect(route.path_list[2].way_points[0].lat).to eq 35.1133325
		expect(route.path_list[2].way_points[0].lon).to eq 135.7049136
	end
end
