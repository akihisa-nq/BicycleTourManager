@echo off

rm -f normal_ne.png normal_e.png normal_nw.png normal_s.png normal_sw.png normal_w.png normal_nw.png
convert -rotate +45  -crop 64x64+0+0 normal_n.png normal_ne.png
convert -rotate +90  -crop 64x64+0+0 normal_n.png normal_e.png
convert -rotate +135 -crop 64x64+0+0 normal_n.png normal_se.png
convert -rotate +180 -crop 64x64+0+0 normal_n.png normal_s.png
convert -rotate +225 -crop 64x64+0+0 normal_n.png normal_sw.png
convert -rotate +270 -crop 64x64+0+0 normal_n.png normal_w.png
convert -rotate +315 -crop 64x64+0+0 normal_n.png normal_nw.png

