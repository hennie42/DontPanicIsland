"""make_towel.py: assets/generated/towel.png, the towel flag's texture: a sunny yellow towel with fringed ends
and a black smiley ("Don't Panic"). Replaces three red/white/blue stripes that read as the Dutch flag.
Run from the project: python3 tools/make_towel.py
"""
from PIL import Image, ImageDraw

W, H, S = 256, 160, 4          # drawn at 4x, then scaled down for smooth edges
im = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
yellow, dark = (255, 210, 63, 255), (214, 150, 20, 255)
d.rounded_rectangle((0, 0, W * S - 1, H * S - 1), radius=10 * S, fill=yellow)
for x0 in (14 * S, W * S - 26 * S):                 # a woven band near each short end
    d.rectangle((x0, 0, x0 + 12 * S, H * S), fill=dark)
for i in range(0, H * S, 12 * S):                   # fringe: little tassels along the short ends
    d.rectangle((0, i + 3 * S, 6 * S, i + 8 * S), fill=dark)
    d.rectangle((W * S - 6 * S, i + 3 * S, W * S, i + 8 * S), fill=dark)
cx, cy, r = W * S // 2, H * S // 2, 52 * S          # the smiley
ink = (25, 25, 30, 255)
d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=ink, width=8 * S)
for ex in (cx - 18 * S, cx + 18 * S):
    d.ellipse((ex - 7 * S, cy - 22 * S, ex + 7 * S, cy - 4 * S), fill=ink)
d.arc((cx - 30 * S, cy - 22 * S, cx + 30 * S, cy + 32 * S), start=20, end=160, fill=ink, width=8 * S)
im.resize((W, H), Image.LANCZOS).save("assets/generated/towel.png")
print("wrote assets/generated/towel.png")
