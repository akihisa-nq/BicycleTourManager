# coding: utf-8

require "spec_helper"

require "bicycle_tour_manager"

include BTM

describe GoogleMapUriParser do
	geocode_cache = PStoreCache.new("test_cache_geocode.db")
	route_cache = PStoreCache.new("test_cache_route.db")
	elevation_cache = PStoreCache.new("test_cache_elevation.db")
	uri = %Q|https://maps.google.co.jp/maps?saddr=%E5%9B%BD%E9%81%93370%E5%8F%B7%E7%B7%9A&daddr=34.1337228,135.4063698+to:%E5%9B%BD%E9%81%93370%E5%8F%B7%E7%B7%9A+to:%E5%9B%BD%E9%81%93480%E5%8F%B7%E7%B7%9A+to:%E6%8C%87%E5%AE%9A%E3%81%AE%E5%9C%B0%E7%82%B9&hl=ja&ie=UTF8&sll=34.18156,135.558243&sspn=0.131926,0.264187&geocode=FXhKCQIdayoQCA%3BFdrWCAIdISMSCCk3Y_DprjsHYDH_V-VlUgwqSg%3BFVrSCQIdGKMTCA%3BFRsMCgId66wUCA%3BFWgKCgIdg-UUCA&dirflg=w&brcurrent=3,0x6006d8c73c814c5d:0xdce24fdf8a7ba5d5,0&mra=mi&mrsp=3&sz=13&via=1&t=m&z=13|

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
end
