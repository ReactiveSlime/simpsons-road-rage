#!/usr/bin/env python3
"""Render a captured PPM/PNG frame as terminal ASCII for headless verification.

This is an analysis aid only: it does not copy, store or redistribute game art.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageOps


def render(path: Path, width: int, height: int, chars: str) -> str:
    with Image.open(path) as image:
        gray = ImageOps.autocontrast(image.convert("L")).resize((width, height))
    pixels = gray.load()
    scale = max(1, 256 // max(1, len(chars)))
    return "\n".join(
        "".join(chars[min(len(chars) - 1, pixels[x, y] // scale)] for x in range(width))
        for y in range(height)
    )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("frame", type=Path)
    parser.add_argument("--width", type=int, default=140)
    parser.add_argument("--height", type=int, default=45)
    parser.add_argument("--chars", default=" .:-=+*#%@")
    args = parser.parse_args()
    print(render(args.frame, args.width, args.height, args.chars))


if __name__ == "__main__":
    main()
