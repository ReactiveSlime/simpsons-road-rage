#!/usr/bin/env python3
"""Regression tests for the project's analysis and validation tools.

The synthetic images here contain no game data; they only exercise structure.
"""

from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / "tools"
sys.path.insert(0, str(TOOLS))

import elf_inspect  # noqa: E402
import frame_stats  # noqa: E402
import iso_inspect  # noqa: E402
import validate_iso  # noqa: E402

SECTOR = iso_inspect.SECTOR


def iso_record(name: str, sector: int, size: int, directory: bool = False) -> bytes:
    name_bytes = name.encode("ascii")
    length = 33 + len(name_bytes)
    padded = length + (length % 2)
    rec = bytearray(padded)
    rec[0] = padded
    rec[2:6] = struct.pack("<I", sector)
    rec[10:14] = struct.pack("<I", size)
    rec[25] = 0x02 if directory else 0x00
    rec[32] = len(name_bytes)
    rec[33:33 + len(name_bytes)] = name_bytes
    return bytes(rec)


def synthetic_sles50540(path: Path, boot: str = r"cdrom0:\SLES_505.40;1") -> None:
    data = bytearray(SECTOR * 20)
    pvd_offset = 16 * SECTOR
    pvd = bytearray(data[pvd_offset:pvd_offset + SECTOR])
    pvd[0] = 1
    pvd[1:6] = b"CD001"
    pvd[80:84] = struct.pack("<I", 20)
    pvd[128:130] = struct.pack("<H", SECTOR)
    pvd[813:830] = validate_iso.EXPECTED["creation_date"].encode("ascii")
    pvd[156:190] = iso_record(".", 17, SECTOR, directory=True)
    data[pvd_offset:pvd_offset + SECTOR] = pvd

    directory = bytearray()
    directory += iso_record("SYSTEM.CNF;1", 18, 56)
    directory += iso_record("SLES_505.40;1", 19, 64)
    data[17 * SECTOR:17 * SECTOR + len(directory)] = directory

    cnf = f"BOOT2 = {boot}\r\nVER = 1.00\r\nVMODE = PAL\r\n".encode("ascii")
    data[18 * SECTOR:18 * SECTOR + len(cnf)] = cnf
    data[19 * SECTOR:19 * SECTOR + 4] = b"\x7fELF"
    path.write_bytes(data)


def synthetic_elf(path: Path) -> None:
    shstr = b"\0.shstrtab\0"
    ehsize, phentsize, shentsize = 52, 32, 40
    phoff = ehsize
    shoff = phoff + phentsize
    code_off = 0x1000
    ident = b"\x7fELF" + bytes([1, 1, 1]) + bytes(9)
    header = ident + struct.pack(
        "<HHIIIIIHHHHHH",
        2, 8, 1,             # ET_EXEC, EM_MIPS, version
        0x00100008, phoff, shoff, 0x20924001,
        ehsize, phentsize, 1, shentsize, 2, 1,
    )
    phdr = struct.pack("<IIIIIIII", 1, code_off, 0x100000, 0x100000, 16, 16, 7, 0x1000)
    null_sh = bytes(shentsize)
    shstr_sh = struct.pack("<IIIIIIIIII", 1, 3, 0, 0, shoff + 2 * shentsize,
                           len(shstr), 0, 0, 1, 0)
    blob = bytearray(header + phdr + null_sh + shstr_sh + shstr)
    blob.extend(bytes(code_off - len(blob)))
    blob.extend(b"\x08\x00\xe0\x03" + bytes(12))
    path.write_bytes(blob)


class IsoInspectTests(unittest.TestCase):
    def test_identifies_synthetic_pal_disc(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / "disc.iso"
            synthetic_sles50540(image)
            found = validate_iso.read_identity(image, hashes=False)
            self.assertEqual(found["boot2"], r"cdrom0:\SLES_505.40;1")
            self.assertEqual(found["vmode"], "PAL")
            self.assertEqual(found["creation_date"], validate_iso.EXPECTED["creation_date"])
            self.assertEqual(found["files"], 2)
            problems = [p for p in validate_iso.check(found, full=False)
                        if not p.startswith(("size:", "sectors:"))]
            self.assertEqual(problems, [])

    def test_rejects_wrong_variant(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / "disc.iso"
            synthetic_sles50540(image, boot=r"cdrom0:\SLES_506.28;1")
            found = validate_iso.read_identity(image, hashes=False)
            problems = validate_iso.check(found, full=False)
            self.assertTrue(any("wrong region/variant" in p for p in problems))

    def test_rejects_wrong_size(self) -> None:
        found = {
            "size": 1, "sectors": 1, "pvd_type": 1, "pvd_id": "CD001",
            "creation_date": validate_iso.EXPECTED["creation_date"],
            "boot2": validate_iso.EXPECTED["boot2"], "vmode": "PAL",
        }
        problems = validate_iso.check(found, full=False)
        self.assertTrue(any(p.startswith("size:") for p in problems))


class ElfInspectTests(unittest.TestCase):
    def test_parses_little_endian_mips_elf(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            elf = Path(tmp) / "SLES_505.40"
            synthetic_elf(elf)
            report = elf_inspect.parse(elf)
            self.assertEqual(report["data"], 1)
            self.assertEqual(report["machine"], 8)
            self.assertEqual(report["entry"], hex(0x00100008))
            self.assertEqual(report["segments"][0]["type"], "LOAD")
            self.assertEqual(report["sections"][1]["name"], ".shstrtab")


class FrameStatsTests(unittest.TestCase):
    def test_summarises_ppm(self) -> None:
        from PIL import Image

        with tempfile.TemporaryDirectory() as tmp:
            image = Path(tmp) / "frame.ppm"
            Image.new("RGB", (4, 2), (16, 32, 48)).save(image)
            result = frame_stats.stats(image)
            self.assertEqual((result["width"], result["height"]), (4, 2))
            self.assertEqual(result["unique_colours"], 1)
            self.assertIn("edge_frac", result)


if __name__ == "__main__":
    unittest.main()
