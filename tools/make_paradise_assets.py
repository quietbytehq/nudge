#!/usr/bin/env python3
"""Builds the Paradise Bay textures from the raw generated art.

    python3 tools/make_paradise_assets.py <raw dir> <table dir>

Raw files expected: floor.png, boards.png (five boards on white), starfish.png,
hibiscus.png, shell.png (on black). Needs ffmpeg and numpy.
"""
import subprocess, sys
import numpy as np

RAW, OUT = sys.argv[1], sys.argv[2]


def ff(*args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def size(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
                          "stream=width,height", "-of", "csv=p=0", path], capture_output=True, text=True).stdout
    w, h = out.strip().split(",")[:2]
    return int(w), int(h)


def load(path):
    w, h = size(path)
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.uint8).reshape(h, w, 3)


def save_rgba(arr, path, height):
    h, w = arr.shape[:2]
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "rgba", "-s", "%dx%d" % (w, h),
                    "-i", "-", "-vf", "scale=-2:%d:flags=lanczos" % height, path], input=arr.tobytes(), check=True)


# playfield print, cropped to the table's proportions
ff("-i", RAW + "/floor.png", "-vf", "crop=1736:3840,eq=saturation=1.06", "-q:v", "1", OUT + "/playfield.jpg")

# plastics sheet: 2 columns x 4 rows. Slings get the starfish, the rest jungle.
ff("-i", RAW + "/starfish.png", "-i", RAW + "/hibiscus.png", "-filter_complex",
   "[0]crop=1280:640,scale=1024:512,eq=gamma=0.85,split=2[s0][s1];"
   "[1]crop=1280:640,scale=1024:512,eq=gamma=0.8,split=6[h0][h1][h2][h3][h4][h5];"
   "[h1]hflip[h1f];[h3]vflip[h3f];[h5]hflip[h5f];"
   "[s0][h0]hstack[r0];[s1][h1f]hstack[r1];[h2][h3f]hstack[r2];[h4][h5f]hstack[r3];"
   "[r0][r1][r2][r3]vstack=inputs=4", "-q:v", "2", OUT + "/plastics.jpg")
ff("-i", RAW + "/hibiscus.png", "-vf", "crop=1280:300:0:210,eq=gamma=0.8", "-q:v", "2", OUT + "/apron.jpg")

# shell light: black background becomes transparent
shell = load(RAW + "/shell.png").astype(np.float32)
h, w = shell.shape[:2]
x0 = (w - h) // 2
shell = shell[:, x0:x0 + h]
alpha = np.clip(shell.max(axis=2) * 3.0, 0, 255)
save_rgba(np.dstack([shell, alpha]).astype(np.uint8), OUT + "/shell.png", 256)

# surfboards: the sheet has a transparent background; cut out each of the five
w, h = size(RAW + "/boards.png")
raw = subprocess.run(["ffmpeg", "-v", "error", "-i", RAW + "/boards.png", "-f", "rawvideo", "-pix_fmt", "rgba", "-"],
                     capture_output=True).stdout
img = np.frombuffer(raw, dtype=np.uint8).reshape(h, w, 4)
ink = img[:, :, 3] > 128
cols = np.where(ink.sum(axis=0) > 3)[0]
runs, start = [], cols[0]
for a, b in zip(cols[:-1], cols[1:]):
    if b - a > 12:
        runs.append((start, a))
        start = b
runs.append((start, cols[-1]))
runs = [r for r in runs if r[1] - r[0] > 60]
assert len(runs) == 5, "expected five boards, found %d" % len(runs)
for i, (c0, c1) in enumerate(runs):
    part = img[:, c0:c1 + 1]
    rows = np.where(ink[:, c0:c1 + 1].any(axis=1))[0]
    part = part[rows[0]:rows[-1] + 1]
    save_rgba(np.ascontiguousarray(part), OUT + "/board_%d.png" % i, 512)
    print("board", i, part.shape[1], "x", part.shape[0])
print("ok")
