@echo off

rm -f orig_ne.png orig_e.png orig_nw.png orig_s.png orig_sw.png orig_w.png orig_nw.png
convert -rotate +45  -crop 64x64+0+0 orig_n.png orig_ne.png
convert -rotate +90  -crop 64x64+0+0 orig_n.png orig_e.png
convert -rotate +135 -crop 64x64+0+0 orig_n.png orig_se.png
convert -rotate +180 -crop 64x64+0+0 orig_n.png orig_s.png
convert -rotate +225 -crop 64x64+0+0 orig_n.png orig_sw.png
convert -rotate +270 -crop 64x64+0+0 orig_n.png orig_w.png
convert -rotate +315 -crop 64x64+0+0 orig_n.png orig_nw.png
