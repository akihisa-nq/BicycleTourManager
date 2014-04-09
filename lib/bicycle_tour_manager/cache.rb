# coding: utf-8

require "pstore"

module BTM
	class PStoreCache
		def initialize(path)
			@path = path
		end

		def cache(key, &value)
			data = nil

			cache = PStore.new(@path)
			cache.transaction do
				data = cache[key]
				if data.nil?
					data = value.call
					cache[key] = data
					cache.commit
				end
			end

			data
		end

		attr_reader :path
	end
end
