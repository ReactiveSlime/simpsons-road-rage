#!/usr/bin/env python3
"""Validate that a disc image is the exact SLES-505.40 PAL build this port targets.

Usage:
    python tools/validate_iso.py --iso <file> [--json REPORT] [--skip-hashes]

The full check hashes the whole image. --skip-hashes still verifies size, PVD,
SYSTEM.CNF, directory structure and the boot ELF name, and is useful in tests
with synthetic images.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import struct
import sys
from pathlib import Path

from iso_inspect import SECTOR, DiscInfo, identify, parse_dir, parse_pvd, read_sectors

EXPECTED = {
    "size": 2_487_582_720,
    "sectors": 1_214_640,
    "pvd_type": 1,
    "pvd_id": "CD001",
    "creation_date": "2001100913023900$",
    "crc32": "a48f9f41",
    "md5": "5a48aa28e65706a13e439d8c7d88af6f",
    "sha1": "ac5949fe278dde9acdc52737e18e17fd3b24e6e5",
    "sha256": "145cf07215352d716b6c908731d764fcab7d31393cc3e421779dbf4e76b2fb10",
    "boot2": r"cdrom0:\SLES_505.40;1",
    "vmode": "PAL",
}

REJECTED = {
    r"cdrom0:\SLES_506.28;1": "the multilingual PAL variant, not this English-only build",
    r"cdrom0:\SLUS_203.05;1": "the NTSC-U release",
}


def read_identity(path: Path, hashes: bool = True) -> dict:
    """Read the fields used for identity checks. Never extracts game data."""
    info = DiscInfo(path=str(path), size=path.stat().st_size, sectors=path.stat().st_size // SECTOR)
    with open(path, "rb") as fh:
        pvd = parse_pvd(fh)
        info.pvd_type = pvd["type"]
        info.pvd_id = pvd["id"]
        info.creation_date = pvd["creation_date"]

        root_rec = read_sectors(fh, 16)[156:190]
        root_sector = struct.unpack_from("<I", root_rec, 2)[0]
        root_size = struct.unpack_from("<I", root_rec, 10)[0]
        parse_dir(fh, root_sector, root_size, "", info.entries)

        if hashes:
            import binascii

            digests = {name: hashlib.new(name) for name in ("md5", "sha1", "sha256")}
            crc = 0
            fh.seek(0)
            while chunk := fh.read(8 * 1024 * 1024):
                for digest in digests.values():
                    digest.update(chunk)
                crc = binascii.crc32(chunk, crc)
            info.md5 = digests["md5"].hexdigest()
            info.sha1 = digests["sha1"].hexdigest()
            info.sha256 = digests["sha256"].hexdigest()
            info.crc32 = f"{crc & 0xffffffff:08x}"

    identity = identify(info)
    return {
        "path": str(path),
        "size": info.size,
        "sectors": info.sectors,
        "pvd_type": info.pvd_type,
        "pvd_id": info.pvd_id,
        "creation_date": info.creation_date,
        "md5": info.md5,
        "sha1": info.sha1,
        "sha256": info.sha256,
        "crc32": info.crc32,
        "boot2": identity["boot2"],
        "vmode": identity["vmode"],
        "files": len(info.entries),
    }


def check(found: dict, full: bool = True) -> list[str]:
    """Return a list of reasons the image is not the required release."""
    problems: list[str] = []
    for key in ("size", "sectors", "pvd_type", "pvd_id", "creation_date", "boot2", "vmode"):
        if found.get(key) != EXPECTED[key]:
            problems.append(f"{key}: expected {EXPECTED[key]!r}, got {found.get(key)!r}")
    why = REJECTED.get(found.get("boot2", ""))
    if why:
        problems.append(f"wrong region/variant: {why}")
    if full:
        for key in ("crc32", "md5", "sha1", "sha256"):
            if found.get(key) != EXPECTED[key]:
                problems.append(f"{key}: expected {EXPECTED[key]!r}, got {found.get(key)!r}")
    return problems


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--iso", required=True, type=Path)
    ap.add_argument("--json", type=Path, default=None)
    ap.add_argument("--skip-hashes", action="store_true")
    args = ap.parse_args()

    if not args.iso.is_file():
        print(f"error: no such image: {args.iso}", file=sys.stderr)
        return 2
    found = read_identity(args.iso, hashes=not args.skip_hashes)
    problems = check(found, full=not args.skip_hashes)
    found["valid"] = not problems
    found["problems"] = problems

    status = "OK" if not problems else "REJECTED"
    print(f"[{status}] {found['path']}")
    print(f"  boot2={found['boot2']!r} vmode={found['vmode']!r} sectors={found['sectors']}")
    if args.skip_hashes:
        print("  hashes: skipped (metadata only)")
    else:
        print(f"  crc32={found['crc32']} sha256={found['sha256']}")
    for problem in problems:
        print(f"  - {problem}", file=sys.stderr)
    if args.json:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(json.dumps(found, indent=2), encoding="utf-8")
        print(f"  report: {args.json}")
    return 0 if not problems else 1


if __name__ == "__main__":
    sys.exit(main())
