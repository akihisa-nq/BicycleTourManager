# coding: utf-8

require "spec_helper"

describe "route2html" do
	it "can generate html file from template file" do
		test_file = File.join(File.dirname(__FILE__), "route.txt")
		test_result = File.join(File.dirname(__FILE__), "result.html")
		bin = File.join(File.dirname(__FILE__), "../bin/route2html")

		if File.exist?(test_result)
			File.delete(test_result)
		end

		expect(system("ruby #{bin} #{test_file}")).to eq true
		expect(File.exist?(test_result)).to eq true

		system("wkhtmltopdf --disable-smart-shrinking -s A5 -O Landscape -L 4mm -R 4mm -T 4mm -B 0mm  #{test_result} #{test_result.gsub(/\.html$/, ".pdf")}")
	end
end
