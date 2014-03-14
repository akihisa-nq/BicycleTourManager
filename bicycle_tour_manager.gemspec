# coding: utf-8

Gem::Specification.new do |spec|
	spec.name = "bicycle_tour_manager"
	spec.version = "0.0.2"
	spec.summary = "自転車旅管理ツール"
	spec.author = "Akihisa Higuchi"
	spec.email = "akihisa.nq@gmail.com"
	spec.homepage = "https://github.com/akihisa-nq/BicycleTourManager"
	spec.files = Dir.glob("{bin,lib,data}/**/*") << "README.txt"
	spec.executables = Dir.glob("bin/**/*").map { |f| File.basename(f) }
	spec.require_paths = ["lib"]
	spec.test_files = Dir.glob("spec/**/*")
	spec.has_rdoc = false
end
