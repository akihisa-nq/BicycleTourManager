# coding: utf-8

require "spec_helper"

def html_to_pdf(path)
	system("wkhtmltopdf --disable-smart-shrinking -s A4 -O Landscape -L 30mm -R 30mm -T 4mm -B 4mm  #{path} #{path.gsub(/\.html$/, ".pdf")}")
end

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

		html_to_pdf(test_result)
	end

	it "can generate support pass node" do
		test_file = File.join(File.dirname(__FILE__), "route_pass.txt")
		test_result = File.join(File.dirname(__FILE__), "result_pass.html")
		bin = File.join(File.dirname(__FILE__), "../bin/route2html")

		if File.exist?(test_result)
			File.delete(test_result)
		end

		expect(system("ruby #{bin} #{test_file} #{test_result}")).to eq true
		expect(File.exist?(test_result)).to eq true

		html_to_pdf(test_result)
	end

	it "can generate support elevation" do
		test_file = File.join(File.dirname(__FILE__), "route_ele.txt")
		test_result = File.join(File.dirname(__FILE__), "result_ele.html")
		bin = File.join(File.dirname(__FILE__), "../bin/route2html")

		if File.exist?(test_result)
			File.delete(test_result)
		end

		expect(system("ruby #{bin} #{test_file} #{test_result}")).to eq true
		expect(File.exist?(test_result)).to eq true

		html_to_pdf(test_result)
	end
end

