@echo off
rm -f dest_ne.png dest_e.png dest_nw.png dest_s.png dest_sw.png dest_w.png dest_nw.png
convert -rotate +45  -crop 64x64+0+0 dest_n.png dest_ne.png
convert -rotate +90  -crop 64x64+0+0 dest_n.png dest_e.png
convert -rotate +135 -crop 64x64+0+0 dest_n.png dest_se.png
convert -rotate +180 -crop 64x64+0+0 dest_n.png dest_s.png
convert -rotate +225 -crop 64x64+0+0 dest_n.png dest_sw.png
convert -rotate +270 -crop 64x64+0+0 dest_n.png dest_w.png
convert -rotate +315 -crop 64x64+0+0 dest_n.png dest_nw.png

