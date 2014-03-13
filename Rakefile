# coding: utf-8

require "fileutils"

GEM_NAME = "bicycle_tour_manager-0.0.2.gem"

images = []
%w{dest normal orig}.each do |type|
	src_image = "data/images/#{type}_n.png"

	%w{ne e se s sw w nw}.each.with_index do |di, i|
		dest_image = "data/images/#{type}_#{di}.png"
		images << dest_image

		file dest_image => src_image  do
			system("convert -rotate +#{45 * (i + 1)}  -crop 64x64+0+0 #{src_image} #{dest_image}")
		end
	end
end

file GEM_NAME => ["bicycle_tour_manager.gemspec", "Rakefile"] + images do
	system("gem build bicycle_tour_manager.gemspec")
end

task :default => GEM_NAME

task :clean do
	FileUtils.rm(images << GEM_NAME, :force => true)
end
