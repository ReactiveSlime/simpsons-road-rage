#!/usr/bin/env python3
"""Inspect a PS2 ISO-9660 disc image, report identity and extract boot files.

Usage:
    python tools/iso_inspect.py --iso <file> [--extract-dir DIR] [--json REPORT]

No copyrighted data is stored in this repository. Extracted files go to the
user-selected working directory and are git-ignored.
"""

from __future__ import annotations

import argparse
import binascii
import hashlib
import json
import os
import struct
import sys
from dataclasses import dataclass, field
from pathlib import Path

SECTOR = 2048


@dataclass
class DirEntry:
    name: str
    sector: int
    size: int
    is_dir: bool
    path: str = ""


@dataclass
class DiscInfo:
    path: str
    size: int
    sectors: int
    pvd_type: int = 0
    pvd_id: str = ""
    volume_id: str = ""
    volume_set_id: str = ""
    publisher: str = ""
    data_preparer: str = ""
    creation_date: str = ""
    md5: str = ""
    sha1: str = ""
    sha256: str = ""
    crc32: str = ""
    first_sector_head: str = ""
    entries: list[DirEntry] = field(default_factory=list)


def read_sectors(fh, sector: int, count: int = 1) -> bytes:
    fh.seek(sector * SECTOR)
    return fh.read(count * SECTOR)


def parse_pvd(fh) -> dict:
    raw = read_sectors(fh, 16)
    if raw[1:6] != b"CD001":
        raise ValueError("No ISO9660 PVD at sector 16")
    def txt(off: int, n: int) -> str:
        return raw[off:off + n].decode("ascii", "replace").rstrip()
    return {
        "type": raw[0],
        "id": raw[1:6].decode("ascii", "replace"),
        "system_id": txt(8, 32),
        "volume_id": txt(40, 32),
        "volume_space_size": struct.unpack_from("<I", raw, 80)[0],
        "volume_set_id": txt(190, 128),
        "publisher": txt(318, 128),
        "data_preparer": txt(446, 128),
        "application": txt(574, 128),
        "creation_date": txt(813, 17),
        "modification_date": txt(830, 17),
        "logical_block_size": struct.unpack_from("<H", raw, 128)[0],
        "path_table_size": struct.unpack_from("<I", raw, 132)[0],
        "l_path_table_lsb": struct.unpack_from("<I", raw, 140)[0],
    }


def parse_dir(fh, sector: int, size: int, prefix: str, out: list[DirEntry]) -> None:
    data = read_sectors(fh, sector, max(1, (size + SECTOR - 1) // SECTOR))
    pos = 0
    while pos < len(data):
        length = data[pos]
        if length == 0:
            pos = (pos // SECTOR + 1) * SECTOR
            if pos >= len(data):
                break
            continue
        if pos + length > len(data):
            break
        entry = data[pos:pos + length]
        name_len = entry[32]
        name = entry[33:33 + name_len].decode("ascii", "replace")
        # Strip ISO trailing semicolon version and directory marker.
        name = name.rstrip("\x00")
        if name in (".", "\x00", ""):
            name = "."
        elif name == "\x01":
            name = ".."
        else:
            name = name.split(";")[0]
        sector_le = struct.unpack_from("<I", entry, 2)[0]
        size_le = struct.unpack_from("<I", entry, 10)[0]
        flags = entry[25]
        is_dir = bool(flags & 0x02)
        child = f"{prefix}/{name}" if prefix else name
        if name not in (".", ".."):
            out.append(DirEntry(name, sector_le, size_le, is_dir, child))
            if is_dir and child.count("/") < 6:
                parse_dir(fh, sector_le, size_le, child, out)
        pos += length


def identify(info: DiscInfo) -> dict:
    names = {e.path.upper() for e in info.entries}
    cnf = next((e for e in info.entries if e.path.upper().endswith("SYSTEM.CNF")), None)
    boot = ""
    vmode = ""
    if cnf:
        fh = open(info.path, "rb")
        data = read_sectors(fh, cnf.sector, max(1, (cnf.size + SECTOR - 1) // SECTOR))[:cnf.size]
        fh.close()
        for line in data.decode("ascii", "replace").splitlines():
            line = line.strip()
            if line.upper().startswith("BOOT2"):
                boot = line.split("=", 1)[1].strip()
            if line.upper().startswith("VMODE"):
                vmode = line.split("=", 1)[1].strip()
    serials = sorted({n.split("/")[-1].split(".")[0] for n in names
                      if n.split("/")[-1].startswith(("SLES", "SLUS", "SCPS", "SLPS"))})
    return {"boot2": boot, "vmode": vmode, "serials": serials}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--iso", required=True)
    ap.add_argument("--extract-dir", default="")
    ap.add_argument("--json", default="")
    ap.add_argument("--list-only", action="store_true")
    args = ap.parse_args()

    iso = Path(args.iso).resolve()
    info = DiscInfo(path=str(iso), size=iso.stat().st_size, sectors=iso.stat().st_size // SECTOR)
    hashes = {k: hashlib.new(k) for k in ("md5", "sha1", "sha256")}
    crc = 0
    with open(iso, "rb") as fh:
        pvd = parse_pvd(fh)
        info.pvd_type = pvd["type"]
        info.pvd_id = pvd["id"]
        info.volume_id = pvd["volume_id"]
        info.volume_set_id = pvd["volume_set_id"]
        info.publisher = pvd["publisher"]
        info.data_preparer = pvd["data_preparer"]
        info.creation_date = pvd["creation_date"]
        fh.seek(0)
        info.first_sector_head = fh.read(64).hex()
        fh.seek(0)
        chunk_size = 8 * 1024 * 1024
        while True:
            chunk = fh.read(chunk_size)
            if not chunk:
                break
            for h in hashes.values():
                h.update(chunk)
            crc = binascii.crc32(chunk, crc)
        for k, h in hashes.items():
            setattr(info, k, h.hexdigest())
        info.crc32 = f"{crc & 0xffffffff:08x}"

        root_sector = struct.unpack_from("<I", read_sectors(fh, 17)[0:0], 0)[0] if False else None
        # Root directory record is at offset 156 of the PVD.
        root_rec = read_sectors(fh, 16)[156:190]
        root_sector = struct.unpack_from("<I", root_rec, 2)[0]
        root_size = struct.unpack_from("<I", root_rec, 10)[0]
        parse_dir(fh, root_sector, root_size, "", info.entries)

    identity = identify(info)
    print(f"Image       : {info.path}")
    print(f"Size        : {info.size} bytes ({info.sectors} sectors)")
    print(f"PVD         : type={info.pvd_type} id={info.pvd_id!r} volume={info.volume_id!r}")
    print(f"Publisher   : {info.publisher!r}")
    print(f"Preparer    : {info.data_preparer!r}")
    print(f"Created     : {info.creation_date!r}")
    print(f"CRC32       : {info.crc32}")
    print(f"MD5         : {info.md5}")
    print(f"SHA1        : {info.sha1}")
    print(f"SHA256      : {info.sha256}")
    print(f"BOOT2       : {identity['boot2']}")
    print(f"VMODE       : {identity['vmode']}")
    print(f"Serials     : {identity['serials']}")
    print(f"Files       : {len(info.entries)}")
    for e in info.entries:
        print(f"  {'D' if e.is_dir else 'F'} {e.sector:8d} {e.size:10d} {e.path}")
    if args.extract_dir:
        out = Path(args.extract_dir)
        out.mkdir(parents=True, exist_ok=True)
        wanted = []
        boot_path = identity["boot2"]
        if boot_path:
            boot_name = boot_path.split("\\")[-1].split(":")[-1].split(";")[0]
            wanted = [e for e in info.entries if e.path.split("/")[-1].upper() == boot_name.upper()]
        wanted += [e for e in info.entries if e.path.upper().endswith(("SYSTEM.CNF", "IOPRP.IMG"))]
        with open(iso, "rb") as fh:
            for e in wanted:
                data = read_sectors(fh, e.sector, max(1, (e.size + SECTOR - 1) // SECTOR))[:e.size]
                target = out / e.path.split("/")[-1]
                target.write_bytes(data)
                print(f"Extracted   : {target} ({len(data)} bytes)")
    if args.json:
        payload = {
            "identity": identity,
            "disc": {k: getattr(info, k) for k in
                     ("path", "size", "sectors", "pvd_type", "pvd_id", "volume_id",
                      "publisher", "data_preparer", "creation_date", "md5", "sha1",
                      "sha256", "crc32", "first_sector_head")},
            "entries": [{"name": e.name, "sector": e.sector, "size": e.size,
                         "is_dir": e.is_dir, "path": e.path} for e in info.entries],
        }
        Path(args.json).write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(f"Report      : {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
