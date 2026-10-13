#!/usr/bin/env python3
"""Measure where a character sits in a video or still, to fill `box:` / `seed:` in 04_clips.yml and size its sprite in the sketch.

usage: sprite_box.py SOURCE green|paper
  green: the character is everything that isn't chroma green; paper: everything far from the paper colour (sampled on the top/bottom rows).
  Videos are sampled every 6th frame and the boxes are unioned (plus a 24px margin), so the box holds the character through its motion.
  H3's extra marks (speed lines, impact ticks) widen the union; the cut-out keeps only the part connected to the seed anyway.
prints JSON (parsed by Media::Python#call): frames sampled, the character's extent [x0, y0, x1, y1], and `box` [x, y, w, h] / `seed` [x, y]
in source pixels, ready for 04_clips.yml.
"""
import json, subprocess, sys, numpy as np
from PIL import Image
src, key = sys.argv[1], sys.argv[2]                       # video or image, "green" | "paper"
if src.endswith((".png", ".jpg")):
    frames = [np.asarray(Image.open(src).convert("RGB")).astype(int)]
else:
    w, h = map(int, subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                                    "-of", "csv=p=0", src], capture_output=True, text=True).stdout.split(",")[:2])
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", src, "-vf", "select=not(mod(n\\,6))", "-fps_mode", "passthrough", "-f", "rawvideo",
                          "-pix_fmt", "rgb24", "-"], capture_output=True).stdout
    frames = list(np.frombuffer(raw, np.uint8).reshape(-1, h, w, 3).astype(int))
boxes = []
for f in frames:
    r, g, b = f[..., 0], f[..., 1], f[..., 2]
    if key == "green":
        fg = (g - np.maximum(r, b)) < 25
    else:
        paper = np.median(np.concatenate([f[:8].reshape(-1, 3), f[-8:].reshape(-1, 3)]), axis=0)
        fg = np.abs(f - paper).sum(-1) > 150
    ys, xs = np.nonzero(fg)
    boxes.append([np.percentile(xs, 1), np.percentile(ys, 1), np.percentile(xs, 99), np.percentile(ys, 99)])
b = np.array(boxes)
x0, y0, x1, y1 = b[:, 0].min(), b[:, 1].min(), b[:, 2].max(), b[:, 3].max()
m = 24                                                    # margin for motion / soft edges
H, W = frames[0].shape[:2]
box = [max(0, int(x0 - m)), max(0, int(y0 - m))]; box += [min(W, int(x1 + m)) - box[0], min(H, int(y1 + m)) - box[1]]
print(json.dumps({"frames_sampled": len(frames), "size": [W, H], "extent": [int(x0), int(y0), int(x1), int(y1)],
                  "box": box, "seed": [int((x0 + x1) / 2), int((y0 + y1) / 2)]}))
