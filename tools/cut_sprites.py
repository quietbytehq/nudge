#!/usr/bin/env python3
"""Cuts painted objects out of a sheet with a transparent background.

    python3 tools/cut_sprites.py <sheet.png> <out prefix> <count> [height]

The sheet holds <count> objects side by side. Each is trimmed to its own
bounds and saved as <out prefix>_<n>.png (or <out prefix>.png when count
is 1), scaled to the given height (default 512). Needs ffmpeg and numpy.
"""
import subprocess, sys
import numpy as np

src, prefix, count = sys.argv[1], sys.argv[2], int(sys.argv[3])
height = int(sys.argv[4]) if len(sys.argv) > 4 else 512
out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                      "-of", "csv=p=0", src], capture_output=True, text=True).stdout.strip().split(",")
w, h = int(out[0]), int(out[1])
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", src, "-f", "rawvideo", "-pix_fmt", "rgba", "-"], capture_output=True).stdout
img = np.frombuffer(raw, dtype=np.uint8).reshape(h, w, 4)
ink = img[:, :, 3] > 100
if ink.mean() > 0.97:
    sys.exit("the sheet has no transparent background: %s" % src)
cols = np.where(ink.sum(axis=0) > 2)[0]
if count == 1:
    runs = [(cols[0], cols[-1])]
else:
    # split at the widest empty gaps
    gaps = sorted(((b - a, a, b) for a, b in zip(cols[:-1], cols[1:]) if b - a > 1), reverse=True)[:count - 1]
    cuts = sorted((a, b) for _, a, b in gaps)
    runs, start = [], cols[0]
    for a, b in cuts:
        runs.append((start, a))
        start = b
    runs.append((start, cols[-1]))
    # objects that touch leave no gap: split the widest piece at its thinnest column
    colsum = ink.sum(axis=0)
    while len(runs) < count:
        k = max(range(len(runs)), key=lambda i: runs[i][1] - runs[i][0])
        a, b = runs[k]
        lo, hi = a + (b - a) * 3 // 10, a + (b - a) * 7 // 10
        cut = lo + int(np.argmin(colsum[lo:hi]))
        runs[k:k + 1] = [(a, cut - 1), (cut + 1, b)]
    if len(runs) != count:
        sys.exit("expected %d objects, found %d" % (count, len(runs)))
for i, (c0, c1) in enumerate(runs):
    part = img[:, c0:c1 + 1]
    rows = np.where(ink[:, c0:c1 + 1].any(axis=1))[0]
    part = np.ascontiguousarray(part[rows[0]:rows[-1] + 1])
    name = "%s.png" % prefix if count == 1 else "%s_%d.png" % (prefix, i)
    ph, pw = part.shape[:2]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", "%dx%d" % (pw, ph), "-i", "-",
                    "-vf", "scale=-2:%d:flags=lanczos" % min(height, ph), name], input=part.tobytes(), check=True)
    print(name, pw, "x", ph)
