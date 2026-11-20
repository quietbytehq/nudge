#!/usr/bin/env python3
"""Builds the app icons from a square icon painting on a black background.

    python3 tools/make_icon.py <source.png>

Writes icon.png (256 px, used by the game window and launcher) and
assets/logo/nudge-512.png (512 px, under 256 KB, used by the packages).
The black outside the rounded square is made transparent. Needs ffmpeg, numpy.
"""
import subprocess, sys
from collections import deque
import numpy as np

src = sys.argv[1]
S = 1024
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", src, "-vf", "scale=%d:%d:flags=lanczos" % (S, S),
                      "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
img = np.frombuffer(raw, dtype=np.uint8).reshape(S, S, 3)
dark = img.max(axis=2) < 30

# flood in from the four corners across the black surround
outside = np.zeros((S, S), dtype=bool)
todo = deque()
for y, x in [(0, 0), (0, S - 1), (S - 1, 0), (S - 1, S - 1)]:
    if dark[y, x]:
        outside[y, x] = True
        todo.append((y, x))
while todo:
    y, x = todo.popleft()
    for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
        if 0 <= ny < S and 0 <= nx < S and dark[ny, nx] and not outside[ny, nx]:
            outside[ny, nx] = True
            todo.append((ny, nx))

alpha = np.where(outside, 0, 255).astype(np.uint8)
rgba = np.dstack([img, alpha])
print("transparent: %.1f%% of the frame" % (100.0 * outside.mean()))


def write(path, size, palette):
    vf = "scale=%d:%d:flags=lanczos" % (size, size)
    if palette:
        vf += ",split[a][b];[a]palettegen=max_colors=255:reserve_transparent=1[p];[b][p]paletteuse=dither=sierra2_4a:alpha_threshold=110"
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", "%dx%d" % (S, S), "-i", "-",
                    "-filter_complex" if palette else "-vf", vf, path], input=rgba.tobytes(), check=True)


write("icon.png", 256, False)
write("assets/logo/nudge-512.png", 512, True)
