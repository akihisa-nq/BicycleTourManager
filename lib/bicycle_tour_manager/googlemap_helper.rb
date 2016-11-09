# coding: utf-8

require "bicycle_tour_manager/route"

module BTM
	module GoogleMapHelper
		BASE_X = 180.0
		BASE_Y = Math.atanh(Math.sin(Math::PI * 85.05112878 / 180.0))

		def self.from_tile_to_lonlat(tx, ty, zoom)
			x = tx.to_f * 360.0 / (2.0 ** zoom) - BASE_X
			y = Math.asin(Math.tanh(- Math::PI * ty.to_f / (2.0 ** (zoom - 1)) + BASE_Y)) * 180.0 / Math::PI
			[x, y]
		end

		def self.tile_bounding_box(tx, ty, zoom)
			x1, y1 = *from_tile_to_lonlat(tx, ty, zoom)
			x2, y2 = *from_tile_to_lonlat(tx + 1, ty + 1, zoom)
			[x1, y1, x2, y2, x2 - x1, y1 - y2]
		end

		def self.from_lonlat_to_tile(x, y, zoom)
			tx = ((x + BASE_X) / 360.0 * (2.0 ** zoom)).to_i
			ty = (- (2.0 ** (zoom - 1)) / Math::PI * (Math.atanh(Math.sin(y * Math::PI / 180.0)) - BASE_Y)).to_i
			[tx, ty]
		end

		def self.lonlat_bounding_box(x1, y1, x2, y2, zoom)
			tx1, ty1 = *from_tile_to_lonlat(x1, y1, zoom)
			tx2, ty2 = *from_tile_to_lonlat(x2, y2, zoom)
			[tx1, ty1, tx2, ty2, tx2 - tx1, ty2 - ty1]
		end

		def self.tile(x1, y1, x2, y2)
			points = [ [ x1, y1 ], [ x2, y1 ], [ x2, y2 ], [ x1, y2 ] ].map {|pt| BTM.factory.point(*pt) }
			view = BTM.factory.polygon(BTM.factory.linear_ring(points))
			view
		end
	end
end
