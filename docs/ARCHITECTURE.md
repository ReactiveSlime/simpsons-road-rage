# Architecture

## Overview

```
User's SLES-505.40 ISO
        │
        ▼
┌───────────────────────────────────────────────────────────────┐
│ This project: validation, analysis, orchestration, packaging   │
│  tools/iso_inspect.py    disc identity + boot ELF extraction   │
│  tools/elf_inspect.py    ELF structure report                  │
│  scripts/build.ps1       builder entry point + build report    │
│  tests/                  reproducible regression checks        │
└───────────────────────────────────────────────────────────────┘
        │  validated ISO + boot program name
        ▼
┌───────────────────────────────────────────────────────────────┐
│ third_party/ps2-native-recomp (MIT, pinned commit)             │
│  [1/6] disc      extract SYSTEM.CNF, boot ELF                  │
│  [2/6] executable  identify ELF, CRC for pnach                 │
│  [3/6] eerecomp   control-flow analysis → 136 C++ units        │
│  [4/6] exploring  headless runs → entries.txt + VU recordings  │
│  [5/6] vurecomp   42 VU1 microprograms → C++                   │
│  [6/6] build      clang/llvm-mingw → build/native-*/ps2run.exe │
└───────────────────────────────────────────────────────────────┘
        │
        ▼
Standalone Windows x64 game (no PCSX2, no BIOS, no installed runtime)
```

## Layering

1. **Guest code layer (statically recompiled).** The R5900 instructions in `.text` become
   literal C++ functions. Branches become goto/labels, calls become native calls, branch
   delay slots are preserved, and the 128-bit GPR/MMI semantics are kept by the runtime's
   instruction helpers. Jump tables and computed jumps are handled by control-flow
   analysis plus entry-point discovery. The game never interprets its own CPU code during
   play, except for code windows first seen at runtime; those are captured, compiled into
   `overlays/` and folded into the next build.

2. **Hardware runtime layer (native C++).** GS, GIF, DMAC, VIF, VU0/VU1, IPU, timers, SIF,
   IOP, SPU2, PAD and memory card are implemented as C++ components. The disc's own ten IRX
   modules execute on the IOP component. Audio uses RADSound's own IRX with host SPU2
   rendering. Rendering goes through wgpu-native to Direct3D 12 (default) or Vulkan.

3. **Host layer.** SDL2 provides the window, keyboard/mouse and XInput-compatible gamepad
   input; the bundled UI provides the key card, quick saves, picture settings and build
   controls.

4. **Project layer (this repo).** Identity validation, repeatable analysis scripts, a thin
   builder wrapper, logs/reports, tests and documentation. It deliberately contains **no**
   game code, assets, ELF bytes, IRX modules or generated C++.

## Why this split

- The upstream tool is generic and actively fixed; keeping it as a pinned dependency means
  fixes to GS/VU/IOP flow into this game without rewriting them here.
- Our validation is game-specific: a wrong-region ISO (e.g. SLES-50628 or SLUS-20305) must
  be rejected before spending minutes on a build.
- Generated C++ is a translation of copyrighted game code; it stays in `generated/` and is
  git-ignored.

## Data flow / caching

- Upstream caches translation units in `generated/roadrage`, VU programs in `games/roadrage/vu1`,
  code windows in `games/roadrage/overlays`, and entry points in `games/roadrage/entries.txt`.
- Rebuilding after a source change only recompiles changed translation units.
- A clean rebuild deletes `generated/roadrage`, `build/native-roadrage` and the game folder,
  then reruns the pipeline from the ISO.

## Build outputs

| Path | Contents |
|---|---|
| `third_party/ps2-native-recomp/build/native-roadrage/ps2run.exe` | native game |
| `third_party/ps2-native-recomp/games/roadrage/disc/` | extracted game data (user-supplied) |
| `third_party/ps2-native-recomp/generated/roadrage/` | generated C++ (derived, not committed) |
| `analysis/*.log`, `analysis/*.json` | evidence and reports |

## Supported builder inputs

- Primary: the ISO in this workspace, SLES-505.40.
- Any path to a byte-identical SLES-505.40 ISO.
- Explicitly rejected: NTSC-U (SLUS-20305), Japanese, GameCube, Xbox, GBA, and the other
  PAL variant SLES-50628. `tools/validate_iso.py` checks size, PVD, `SYSTEM.CNF`, CRC32
  and all hashes; `scripts/build.ps1` runs it before every build.

## Failure handling

- Every pipeline stage writes its output to a log under `build/` or `analysis/`.
- `scripts/build.ps1` stops on the first failed stage and prints the relevant log tail.
- Unsupported instructions/hardware are surfaced by upstream's generated `// Unhandled`
  markers and runtime logs; they are recorded in `COMPATIBILITY.md` rather than ignored.
