#!/usr/bin/env python3
"""Parse a PS2 (R5900) ELF and emit a structured report as JSON.

PS2 retail ELFs are 32-bit, little-endian, MIPS, ET_EXEC. This tool is
endian-aware and intentionally reads only structure: it never needs or stores
copyrighted asset contents.
"""

from __future__ import annotations

import argparse
import json
import struct
import sys
from pathlib import Path

PT = {0: "NULL", 1: "LOAD", 2: "DYNAMIC", 3: "INTERP", 4: "NOTE", 5: "SHLIB", 6: "PHDR"}
PF = {1: "X", 2: "W", 4: "R"}
SHT = {0: "NULL", 1: "PROGBITS", 2: "SYMTAB", 3: "STRTAB", 4: "RELA", 5: "HASH",
       6: "DYNAMIC", 7: "NOTE", 8: "NOBITS", 9: "REL", 14: "INIT_ARRAY", 15: "FINI_ARRAY",
       16: "PREINIT_ARRAY", 17: "GROUP", 18: "SYMTAB_SHNDX"}
STT = {0: "NOTYPE", 1: "OBJECT", 2: "FUNC", 3: "SECTION", 4: "FILE", 5: "COMMON", 6: "TLS"}
STB = {0: "LOCAL", 1: "GLOBAL", 2: "WEAK"}


def parse(path: Path) -> dict:
    data = path.read_bytes()
    if data[:4] != b"\x7fELF":
        raise ValueError("Not an ELF")
    ei_class, ei_data = data[4], data[5]
    if ei_class != 1:
        raise ValueError(f"Expected ELF32, got class={ei_class}")
    endian = "<" if ei_data == 1 else ">"
    def u16(off: int) -> int:
        return struct.unpack_from(endian + "H", data, off)[0]
    def u32(off: int) -> int:
        return struct.unpack_from(endian + "I", data, off)[0]
    e_type, e_machine, e_version = u16(16), u16(18), u32(20)
    e_entry, e_phoff, e_shoff, e_flags = u32(24), u32(28), u32(32), u32(36)
    e_ehsize, e_phentsize, e_phnum, e_shentsize, e_shnum, e_shstrndx = (
        u16(40), u16(42), u16(44), u16(46), u16(48), u16(50))

    out = {
        "path": str(path), "size": len(data),
        "class": ei_class, "data": ei_data,
        "type": e_type, "machine": e_machine, "flags": hex(e_flags),
        "entry": hex(e_entry), "phnum": e_phnum, "shnum": e_shnum,
        "segments": [], "sections": [], "symbols": [], "relocations": [],
    }

    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_flags, p_align = (
            u32(off), u32(off + 4), u32(off + 8), u32(off + 12),
            u32(off + 16), u32(off + 20), u32(off + 24), u32(off + 28))
        out["segments"].append({
            "index": i, "type": PT.get(p_type, str(p_type)), "offset": hex(p_offset),
            "vaddr": hex(p_vaddr), "filesz": p_filesz, "memsz": p_memsz,
            "flags": "".join(c for bit, c in PF.items() if p_flags & bit),
            "align": hex(p_align),
        })

    shstr = b""
    if e_shnum and e_shstrndx < e_shnum:
        off = e_shoff + e_shstrndx * e_shentsize
        so, ss = u32(off + 16), u32(off + 20)
        shstr = data[so:so + ss]

    def cstr(blob: bytes, off: int) -> str:
        if off >= len(blob):
            return ""
        end = blob.find(b"\0", off)
        return blob[off:end if end >= 0 else len(blob)].decode("ascii", "replace")

    sections = []
    for i in range(e_shnum):
        off = e_shoff + i * e_shentsize
        name, s_type, s_flags, addr, offset, size, link, info, align, entsize = (
            u32(off), u32(off + 4), u32(off + 8), u32(off + 12), u32(off + 16),
            u32(off + 20), u32(off + 24), u32(off + 28), u32(off + 32), u32(off + 36))
        sections.append({
            "index": i, "name": cstr(shstr, name), "name_off": name,
            "type": SHT.get(s_type, str(s_type)), "flags": hex(s_flags),
            "addr": hex(addr), "offset": offset, "size": size,
            "link": link, "info": info, "align": align, "entsize": entsize,
        })
    out["sections"] = sections

    symtabs = [s for s in sections if s["type"] == "SYMTAB"]
    for st in symtabs:
        linked = sections[st["link"]] if st["link"] < len(sections) else None
        strings = data[linked["offset"]:linked["offset"] + linked["size"]] if linked else b""
        n = st["size"] // 16
        funcs, objects = [], []
        imports = []
        for i in range(n):
            off = st["offset"] + i * 16
            name_off, value, size = u32(off), u32(off + 4), u32(off + 8)
            info, other, shndx = data[off + 12], data[off + 13], u16(off + 14)
            name = cstr(strings, name_off)
            bind, typ = info >> 4, info & 0xF
            if name and (bind == 1 or typ == 2):
                rec = {"name": name, "value": hex(value), "size": size,
                       "bind": STB.get(bind, str(bind)), "type": STT.get(typ, str(typ)),
                       "shndx": shndx}
                if shndx == 0 and value == 0:
                    imports.append(name)
                elif typ == 2:
                    funcs.append(rec)
                elif typ == 1:
                    objects.append(rec)
        out["symbols"].append({"section": st["name"], "count": n,
                               "funcs": funcs, "objects": objects[:50],
                               "object_count": len(objects), "imports": imports})

    rels = [s for s in sections if s["type"] in ("REL", "RELA")]
    for rs in rels:
        entry_size = 8 if rs["type"] == "REL" else 12
        count = rs["size"] // entry_size if entry_size else 0
        sample = []
        for i in range(min(count, 20)):
            off = rs["offset"] + i * entry_size
            r_offset, r_info = u32(off), u32(off + 4)
            addend = struct.unpack_from(endian + "i", data, off + 8)[0] if rs["type"] == "RELA" else 0
            sample.append({"offset": hex(r_offset), "sym": r_info >> 8,
                           "type": r_info & 0xFF, "addend": addend})
        out["relocations"].append({"section": rs["name"], "type": rs["type"],
                                   "count": count, "sample": sample})
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("elf")
    ap.add_argument("--json", default="")
    args = ap.parse_args()
    report = parse(Path(args.elf))
    print(f"File    : {report['path']} ({report['size']} bytes)")
    print(f"Type    : {report['type']} machine={report['machine']} flags={report['flags']}")
    print(f"Entry   : {report['entry']}  segments={report['phnum']} sections={report['shnum']}")
    print("Segments:")
    for s in report["segments"]:
        print(f"  {s['index']:2} {s['type']:6} vaddr={s['vaddr']:>10} "
              f"off={s['offset']:>10} filesz={s['filesz']:9} memsz={s['memsz']:9} {s['flags']}")
    print("Sections:")
    for s in report["sections"]:
        print(f"  {s['index']:2} {s['name']:20} {s['type']:10} addr={s['addr']:>10} "
              f"off={s['offset']:10} size={s['size']:9} link={s['link']}")
    for st in report["symbols"]:
        print(f"Symbols : {st['section']} count={st['count']} funcs={len(st['funcs'])} "
              f"objects={st['object_count']} imports={len(st['imports'])}")
        for f in st["funcs"][:25]:
            print(f"    FUNC {f['value']:>10} +{f['size']:<7} {f['name']}")
        for imp in st["imports"][:60]:
            print(f"    UND  {imp}")
    for r in report["relocations"]:
        print(f"Relocs  : {r['section']} type={r['type']} count={r['count']}")
        for x in r["sample"][:10]:
            print(f"    {x}")
    if args.json:
        Path(args.json).write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(f"Report  : {args.json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
