#!/usr/bin/env python3
"""Trim, clean and normalise generated sound effects for the game.

Usage: process_sfx.py [<raw dir> <output dir>]
Reads assets/sfx_raw/<name>_<n>.mp3 and writes assets/sfx/<name>_<n>.wav
(mono, 44.1 kHz, 16-bit). One-shot impact sounds are cut to their first hit so
every sample starts instantly and stays short. Needs ffmpeg.
"""
import array, math, os, subprocess, sys, wave

RATE = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "sfx_raw")
DST = os.path.join(ROOT, "assets", "sfx")
# name -> (max seconds, keep only the first hit)
SPEC = {
    "flipper": (0.35, True), "flipper_down": (0.30, True), "bumper": (0.55, True),
    "sling": (0.35, True), "target": (0.9, False), "rollover": (0.7, False),
    "metal": (0.25, True), "rubber": (0.25, True), "ball": (0.2, True),
    "launch": (1.6, False), "drain": (2.2, False), "bonus": (1.8, False),
    "start": (3.0, False), "ambient": (12.0, False),
}


def decode(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE),
                          "-f", "s16le", "-"], capture_output=True, check=True).stdout
    a = array.array("h")
    a.frombytes(raw)
    return [s / 32768.0 for s in a]


def envelope(x, win=220):          # 5 ms peak envelope
    return [max(abs(v) for v in x[i:i + win]) for i in range(0, len(x), win)]


def process(name, x):
    max_len, first_hit = SPEC[name]
    env = envelope(x)
    peak = max(env) if env else 0.0
    if peak < 0.01:
        return None, 0
    win = 220
    start = next(i for i, e in enumerate(env) if e > peak * 0.06)
    # count separate hits: envelope rising above 35% of peak after a quiet gap
    hits, quiet, hit_frames = 0, 99, []
    for i, e in enumerate(env):
        if e > peak * 0.35:
            if quiet >= 14:        # 70 ms of relative quiet first
                hits += 1
                hit_frames.append(i)
            quiet = 0
        elif e < peak * 0.12:
            quiet += 1
    end = len(env)
    if first_hit and len(hit_frames) > 1:
        end = hit_frames[1] - 3
    # stop where the tail has died away
    last = start
    for i in range(start, end):
        if env[i] > peak * 0.012:
            last = i
    end = min(end, last + 4, start + int(max_len * RATE / win))
    s0 = max(0, start * win - 64)
    seg = x[s0:end * win]
    if len(seg) < RATE * 0.02:
        return None, hits
    pk = max(abs(v) for v in seg)
    gain = 0.89 / pk
    fade = min(len(seg) // 3, int(RATE * 0.03))
    out = []
    n = len(seg)
    for i, v in enumerate(seg):
        g = gain
        if i < 32:
            g *= i / 32.0
        if i >= n - fade:
            g *= (n - i) / fade
        out.append(int(max(-1.0, min(1.0, v * g)) * 32767))
    return out, hits


def main():
    global SRC, DST
    if len(sys.argv) == 3:          # process_sfx.py <raw dir> <output dir>
        SRC, DST = sys.argv[1], sys.argv[2]
    os.makedirs(DST, exist_ok=True)
    for f in os.listdir(DST):
        if f.endswith(".wav"):
            os.remove(os.path.join(DST, f))
    print("%-18s %5s %7s %7s" % ("file", "hits", "raw s", "out s"))
    for fn in sorted(os.listdir(SRC)):
        if not fn.endswith(".mp3"):
            continue
        stem = fn[:-4]
        name = stem.rsplit("_", 1)[0] if stem[-1].isdigit() else stem
        if name not in SPEC:
            continue
        x = decode(os.path.join(SRC, fn))
        out, hits = process(name, x)
        if out is None:
            print("%-18s %5d %7.2f   silent/skipped" % (stem, hits, len(x) / RATE))
            continue
        with wave.open(os.path.join(DST, stem + ".wav"), "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(array.array("h", out).tobytes())
        print("%-18s %5d %7.2f %7.2f" % (stem, hits, len(x) / RATE, len(out) / RATE))


if __name__ == "__main__":
    sys.exit(main())
