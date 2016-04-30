# coding: utf-8

require "spec_helper"

require "bicycle_tour_manager"

include BTM

describe GoogleMapUriParser do
	uri_new = %Q|https://www.google.co.jp/maps/dir/35.1156642,135.713829/35.1129261,135.7104386/35.1116974,135.7049884/@35.1210211,135.7066495,15z/am=t/data=!3m1!4b1!4m10!4m9!1m0!1m5!3m4!1m2!1d135.7001757!2d35.1236666!3s0x6001aef192cc015d:0xb71a1a272c111f30!1m0!3e2?hl=ja|
	uri_new2 = %Q|https://www.google.co.jp/maps/dir/35.1156642,135.713829/35.1129261,135.7104386/35.1139477,135.7058341/35.1116974,135.7049884/@35.1210211,135.7066495,15z/am=t/data=!3m1!4b1!4m16!4m15!1m0!1m5!3m4!1m2!1d135.7001757!2d35.1236666!3s0x6001aef192cc015d:0xb71a1a272c111f30!1m5!3m4!1m2!1d135.7049136!2d35.1133325!3s0x6001aedcc642ac1d:0xc62b7b6903ce7aa!1m0!3e2?hl=ja|
	uri_new3 = %Q|https://www.google.co.jp/maps/dir/35.0661703,136.635521/35.0654188,136.6309173/35.062558,136.6337807/35.004935,136.6089968/34.9997875,136.6012395/34.9754106,136.5976834/35.0135647,136.5005051/@35.0081947,136.6054488,15.55z/data=!4m29!4m28!1m0!1m0!1m15!3m4!1m2!1d136.6292395!2d35.0516189!3s0x600391008e9f97c9:0x32cd5d1027e0e1f2!3m4!1m2!1d136.6329801!2d35.031899!3s0x60039034da6a071d:0x732d043af709d70f!3m4!1m2!1d136.6061793!2d35.0072299!3s0x600391e24acec47b:0x3e6b2ad9b8b980c0!1m0!1m0!1m5!3m4!1m2!1d136.5146505!2d35.0127184!3s0x6003eccc91c4a8e9:0x70cf7dde3ff04bc2!1m0!3e2?hl=ja|

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

	it "can analyze new format 3" do
		parser = GoogleMapUriParser.new(nil)
		route = parser.parse_uri(uri_new3)
		expect(route).not_to eq nil
		expect(route.path_list.length).to eq(6)

		expect(route.path_list[2].way_points.length).to eq(3)
		expect(route.path_list[2].way_points[0].lat).to eq 35.0516189
		expect(route.path_list[2].way_points[1].lat).to eq 35.031899
		expect(route.path_list[2].way_points[2].lat).to eq 35.0072299

		expect(route.path_list[5].way_points.length).to eq(1)
		expect(route.path_list[5].way_points[0].lat).to eq 35.0127184
	end
end
