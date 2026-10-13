#!/usr/bin/env python3
"""Cut a character out of a video (or still) into a transparent PNG sequence, for p5 sprites.

usage: cutout.py SOURCE OUT_DIR KEY [--box X Y W H] [--seed X Y] [--frames N] [--start N] [--scale S] [--tol T]
  SOURCE  video or image; KEY is "green" (flat chroma-key background), "paper" (cream paper background) or "none"
          (no keying: the crop stays fully opaque, for full-frame scene clips that contain green, e.g. plants)
  --box   crop in source pixels (default: the whole frame); --seed a point on the character (default: box centre)
  --frames / --start  which frames of a video (default: all from 0); --scale  resize the cut-outs (default 1)
  --tol   paper colour tolerance (default 28, RGB distance after a median filter)
paper: the background is the paper connected to the crop border (flood fill on a median-filtered copy, so paper grain
does not stop it and the character's cream skin/face, enclosed by its outlines, stays opaque); then only the component
under --seed is kept (drops loose strokes such as speed lines). green: alpha from green dominance, with despill.
Writes OUT_DIR/0000.png … and prints JSON {"frames", "w", "h", "box", "src" (source frame size), "scale"}.
"""
import argparse
import json
import os
import subprocess

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


def frames(source, start, count):
    if os.path.splitext(source)[1].lower() in (".png", ".jpg", ".jpeg", ".webp"):
        yield Image.open(source).convert("RGB")
        return
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
                          "-of", "csv=p=0", source], capture_output=True, check=True, text=True).stdout
    w, h = map(int, out.strip().split(",")[:2])
    vf = f"select=gte(n\\,{start})" + (f"*lt(n\\,{start + count})" if count else "")
    proc = subprocess.Popen(["ffmpeg", "-v", "error", "-i", source, "-vf", vf, "-fps_mode", "passthrough", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
                            stdout=subprocess.PIPE)
    size = w * h * 3
    while (buf := proc.stdout.read(size)) and len(buf) == size:
        yield Image.frombuffer("RGB", (w, h), buf)
    proc.wait()


def paper_alpha(img, seed, tol):
    small = img.resize((img.width // 4, img.height // 4), Image.BILINEAR).filter(ImageFilter.MedianFilter(5))
    w, h = small.size
    mark = (255, 0, 255)
    for x, y in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1), (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]:
        if small.getpixel((x, y)) != mark:
            ImageDraw.floodfill(small, (x, y), mark, thresh=tol)
    # .copy(): PIL's floodfill is a silent no-op on the read-only images Image.fromarray makes
    fg = Image.fromarray(np.where((np.asarray(small) == mark).all(-1), 0, 255).astype(np.uint8)).copy()
    # keep the component under the seed (fill it grey, then keep grey)
    sx, sy = min(w - 1, seed[0] // 4), min(h - 1, seed[1] // 4)
    if fg.getpixel((sx, sy)) == 255:
        ImageDraw.floodfill(fg, (sx, sy), 128)
        fg = Image.fromarray(np.where(np.asarray(fg) == 128, 255, 0).astype(np.uint8))
    return fg.resize(img.size, Image.BILINEAR).filter(ImageFilter.GaussianBlur(1))


def green_alpha(img):
    a = np.asarray(img).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    dom = g - np.maximum(r, b)                               # how much greener than the other channels
    alpha = np.clip(255 - (dom - 25) * 6, 0, 255).astype(np.uint8)
    return Image.fromarray(alpha).filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))


def despill(img):
    a = np.asarray(img).astype(np.int16)
    a[..., 1] = np.minimum(a[..., 1], np.maximum(a[..., 0], a[..., 2]) + 10)
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


def main():
    p = argparse.ArgumentParser()
    p.add_argument("source"); p.add_argument("out"); p.add_argument("key", choices=["green", "paper", "none"])
    p.add_argument("--box", type=int, nargs=4); p.add_argument("--seed", type=int, nargs=2)
    p.add_argument("--frames", type=int, default=0); p.add_argument("--start", type=int, default=0)
    p.add_argument("--scale", type=float, default=1.0); p.add_argument("--tol", type=int, default=28)
    o = p.parse_args()
    os.makedirs(o.out, exist_ok=True)
    n = 0
    for img in frames(o.source, o.start, o.frames):
        src = [img.width, img.height]
        box = o.box or [0, 0, img.width, img.height]
        img = img.crop((box[0], box[1], box[0] + box[2], box[1] + box[3]))
        seed = [o.seed[0] - box[0], o.seed[1] - box[1]] if o.seed else [box[2] // 2, box[3] // 2]
        rgba = (despill(img) if o.key == "green" else img).convert("RGBA")
        if o.key != "none":
            rgba.putalpha(green_alpha(img) if o.key == "green" else paper_alpha(img, seed, o.tol))
        if o.scale != 1:
            rgba = rgba.resize((round(rgba.width * o.scale), round(rgba.height * o.scale)), Image.LANCZOS)
        rgba.save(os.path.join(o.out, f"{n:04d}.png"))
        n += 1
    print(json.dumps({"frames": n, "w": rgba.width, "h": rgba.height, "box": box, "src": src, "scale": o.scale}))


if __name__ == "__main__":
    main()
