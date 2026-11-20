# Baseline report: workspace audit (2026-11-20)

> This is the historical starting-point report. Later milestones that reach the
> title screen, main menu and gameplay are documented in `PROGRESS.md` and
> `COMPATIBILITY.md`; where this report says "not yet", read that as "not yet at
> the time of the initial 600-frame baseline".

## Scope

The workspace `D:\Games\RECOMPS\WIP_GAMES\simpson_road_rage` was inspected in full before any
source was added.

## What existed before this work

| Item | State |
|---|---|
| `Simpsons Road Rage PS2 PAL.iso` | Present, 2,487,582,720 bytes, 1,214,640 sectors |
| Source code | **None** |
| Reverse-engineering work | **None** |
| Disassembly / ELF analysis | **None** |
| Memory maps / function DBs | **None** |
| Recompilation experiments | **None** |
| Build scripts / toolchain config | **None** |
| Runtime implementations | **None** |
| Git repository | **None** (initialised during this work) |
| Previous errors / failed experiments | None recorded |

The workspace was effectively a clean slate with one user-supplied disc image. Nothing was
overwritten or deleted. All new files live alongside the ISO.

## What works now (measured, not assumed)

1. Disc identification and ISO-9660 parsing (`tools/iso_inspect.py`).
2. Boot ELF parsing: `tools/elf_inspect.py` (little-endian ELF32, EM_MIPS).
3. Upstream `ps2-native-recomp` toolchain installed and built on this host.
4. Static recompilation of SLES_505.40: 136 generated translation units, native Windows
   executable produced (`build/port_baseline.log`).
5. The produced executable actually boots the game: IRX loading, SIF/IOP, RADSound,
   memory-card driver, GS init, D3D12 rendering, 600 frames executed and 10 frames captured
   (`analysis/run_baseline.log`, `analysis/shots_baseline/`).

## What partially works

- Baseline boot reaches rendered frames, but the 600-frame captures are mostly black with
  small coloured regions. Later runs showed this is the pre-title FMV/fade sequence; see
  `PROGRESS.md` for menu and gameplay confirmation.
- VU microprograms were not compiled in the original cold baseline ("none recorded"): the
  runtime interprets them and compiles pages on the fly. The later exploratory build
  recorded 42 VU1 programs (`build/port_explore.log`). `build/port_baseline.log` was
  regenerated with a warm VU cache while testing `scripts/build.ps1`, so it now lists
  those cached programs; the cold-cache result is recorded above and in
  `GAME_ANALYSIS.md`.
- Runtime overlays are not yet enumerated from the ELF's `.DVP.overlay*` sections; upstream
  discovers dynamically loaded code at runtime via `overlays/` capture instead.

## What does not work / is unverified

- At baseline there was no evidence for the main menu, gameplay, input or save/load.
  Scripted input and rendering are now verified; save/load and audio remain open.
- The game's 8 DVP overlays have not been explicitly translated ahead of time.
- `RADSOUND.IRX` is a proprietary module; upstream runs the disc's own IRX modules, which
  is working so far, but audible output has not been verified.
- PCSX2's wiki marks this game as "software rendering only"; a PS2 hardware-rendering
  quirk may need investigation if GS output is wrong.

## What has not been investigated

- Full playthrough, mission completion, two-player split screen.
- PAL timing/resolution differences beyond `VMODE = PAL` (the runtime reproduces PAL GS
  display settings; no separate PAL patch has been applied).
- `.DVP.ovlytab` semantics (eight 12-byte records, see `GAME_ANALYSIS.md`).
- Pure3D `.RCF`/`.DAT` asset formats — consumed by the original game code, so no parser is
  needed for recompilation unless assets require preprocessing.
- Performance profile beyond the first 600 frames.

## Reusable existing components

- **Upstream `ps2-native-recomp` (MIT)**: EE static recompiler, C++ runtime (GS/VU0/VU1/IOP/
  DMA/SIF/SPU2/IPU), D3D12/Vulkan rendering via wgpu-native, SDL2 window/input, PCSX2
  pnach support, overlay capture, builder app. This is now the foundation.
- `ps2-web-recomp` (MIT, upstream of upstream): shared lineage, not used directly.
- Our own `tools/iso_inspect.py` and `tools/elf_inspect.py` for repeatable analysis.

## Components replaced or not adopted

- A from-scratch R5900 recompiler was **not** written: upstream already implements MIPS III,
  MMI, FPU, VU0 macro mode, branch delay slots and 128-bit GPRs, with a test suite. Writing
  a new one would discard a working, tested implementation.
- `ran-j/PS2Recomp` (GPL-3.0) was **not** adopted: at the time of inspection it had no
  playable game, GS/VU1/DMA stubbed, and requires Ghidra function maps per game. Its GPL
  licence would also constrain the builder. See `RESEARCH.md`.
- `open-goal/jak-project` was **not** adopted: it depends on a custom LISP compiler and
  years of manual decompilation specific to Naughty Dog titles; not transferable to a
  Radical Entertainment C++/Pure3D game within this project.

## Baseline evidence

- `analysis/disc_inventory.json`, `analysis/elf_report.json`
- `build/upstream_setup.log`, `build/port_baseline.log`
- `analysis/run_baseline.log`, `analysis/shots_baseline/`
