"""make_green_colormap.py: assets/generated/colormap_green.png, the hexagon kit's colour atlas with its teal swatch
(grass, forest) shifted to a leafy green. Only the grass and jungle tiles use it (board_view.gd); sand, rock and
water keep the original. Run from the project: python3 tools/make_green_colormap.py
"""
import colorsys

from PIL import Image

SRC = "assets/kenney/hexagon-kit/Models/GLB format/Textures/colormap.png"
DST = "assets/generated/colormap_green.png"

im = Image.open(SRC).convert("RGBA")
px = im.load()
changed = 0
for y in range(im.size[1]):
    for x in range(im.size[0]):
        r, g, b, a = px[x, y]
        h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
        if 150 / 360 <= h <= 190 / 360 and s > 0.3:
            nr, ng, nb = colorsys.hsv_to_rgb(118 / 360, s * 0.72, v * 0.78)   # the scheme adds saturation on top
            px[x, y] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
            changed += 1
im.save(DST)
print(f"wrote {DST}: {changed} pixels recoloured")
