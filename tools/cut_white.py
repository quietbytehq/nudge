"""Cut an object out of a plain white background: flood-fills the near-white
area connected to the image border, then trims to the object.
Usage: cut_white.py <in> <out.png> [height] [crop x0,y0,x1,y1]"""
import sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops
src, dst = sys.argv[1], sys.argv[2]
height = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3] != "-" else 0
im = Image.open(src).convert("RGB")
if len(sys.argv) > 4:
    im = im.crop(tuple(int(v) for v in sys.argv[4].split(",")))
w, h = im.size
r, g, b = im.split()
lo = ImageChops.darker(ImageChops.darker(r, g), b)
hi = ImageChops.lighter(ImageChops.lighter(r, g), b)
# near white: bright and grey (low spread)
spread = ImageChops.subtract(hi, lo)
white = Image.eval(lo, lambda v: 255 if v > 226 else 0)
grey = Image.eval(spread, lambda v: 255 if v < 22 else 0)
mask = ImageChops.multiply(white, grey)
for x in range(0, w, 8):
    for y in (0, h - 1):
        if mask.getpixel((x, y)) == 255:
            ImageDraw.floodfill(mask, (x, y), 128)
for y in range(0, h, 8):
    for x in (0, w - 1):
        if mask.getpixel((x, y)) == 255:
            ImageDraw.floodfill(mask, (x, y), 128)
alpha = Image.eval(mask, lambda v: 0 if v == 128 else 255)
alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
im.putalpha(alpha)
bb = alpha.point(lambda v: 255 if v > 128 else 0).getbbox()
im = im.crop(bb)
if height:
    im = im.resize((round(im.width * height / im.height), height), Image.LANCZOS)
im.save(dst)
print(dst, im.size)
