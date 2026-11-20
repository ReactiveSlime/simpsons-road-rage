#!/usr/bin/env python3
"""Summarise captured PS2 frames without displaying copyrighted imagery.

Usage: python tools/frame_stats.py <dir> [--csv report.csv]

Prints only numeric statistics (brightness, colour count, edge density) so a build
can be assessed from logs. Uses Pillow if available, otherwise a small P6 reader.
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path


def load_ppm(path: Path):
    try:
        from PIL import Image
        im = Image.open(path).convert("RGB")
        pixels = im.get_flattened_data() if hasattr(im, "get_flattened_data") else im.getdata()
        return list(pixels), im.size
    except ImportError:
        pass
    raw = path.read_bytes()
    # P6 magic, width height, maxval, then one packed RGB plane.
    parts, pos = [], 0
    for _ in range(3):
        while pos < len(raw) and raw[pos] in b" \t\r\n":
            pos += 1
        start = pos
        while pos < len(raw) and raw[pos] not in b" \t\r\n":
            pos += 1
        parts.append(raw[start:pos])
    if parts[0] != b"P6":
        raise ValueError(f"not a PPM: {path}")
    w, h, maxv = int(parts[1]), int(parts[2]), int(parts[3])
    pos += 1
    px = raw[pos:pos + w * h * 3]
    return [(px[i], px[i + 1], px[i + 2]) for i in range(0, len(px) - 2, 3)], (w, h)


def stats(path: Path) -> dict:
    pixels, size = load_ppm(path)
    n = max(len(pixels), 1)
    lum = [0.299 * r + 0.587 * g + 0.114 * b for r, g, b in pixels]
    nonblack = sum(1 for v in lum if v > 12) / n
    bright = sum(1 for v in lum if v > 96) / n
    colours = len(set(pixels))
    # Neighbour difference is a cheap proxy for text/detail density.
    w, _ = size
    edges = 0
    checked = 0
    for i in range(0, n - 1):
        if i % w == w - 1:
            continue
        checked += 1
        a, b = pixels[i], pixels[i + 1]
        if abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2]) > 48:
            edges += 1
    return {
        "frame": path.name,
        "width": w,
        "height": size[1],
        "mean_luma": round(sum(lum) / n, 3),
        "nonblack_frac": round(nonblack, 4),
        "bright_frac": round(bright, 4),
        "unique_colours": colours,
        "edge_frac": round(edges / max(checked, 1), 4),
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("dir")
    ap.add_argument("--csv", default="")
    args = ap.parse_args()
    rows = [stats(p) for p in sorted(Path(args.dir).glob("*.ppm"))]
    if not rows:
        print("no .ppm frames found", file=sys.stderr)
        return 1
    cols = ["frame", "width", "height", "mean_luma", "nonblack_frac",
            "bright_frac", "unique_colours", "edge_frac"]
    print(" | ".join(cols))
    for r in rows:
        print(" | ".join(str(r[c]) for c in cols))
    if args.csv:
        with open(args.csv, "w", newline="", encoding="utf-8") as fh:
            w = csv.DictWriter(fh, fieldnames=cols)
            w.writeheader()
            w.writerows(rows)
        print(f"wrote {args.csv}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
