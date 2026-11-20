# Research: PS2 native recompilation ecosystem

Investigated 2026-11-20. Claims below are cross-checked against READMEs, source files,
commit history and third-party catalogues (Recompendium/Recompedia) where possible. This
project deliberately did not rely on README descriptions alone.

## 1. Projects examined

### 1.1 `exoteric33/ps2-native-recomp` — SELECTED

| Property | Finding |
|---|---|
| Status | Created 2026-10-28, 193+ commits; latest commit inspected `74912bd` (2026-11-19). Released v0.0.5 on 2026-11-09. Actively maintained. |
| Licence | **MIT** (and its upstream `snuri00/ps2-web-recomp` is MIT). |
| Method | Static recompilation of EE (R5900) machine code to C++; the rest of the console is a native C++ runtime. |
| Runtime | GS (WebGPU via wgpu-native → D3D12 or Vulkan), VU0/VU1 (ahead-of-time + on-the-fly JIT pages), IOP running the disc's own IRX modules, IPU, SPU2, SIF, DMAC, timers, PAD/memory card. |
| Standalone EXE | **Yes.** Builds `ps2run.exe` per game; desktop shortcut via the bundled app. |
| BIOS | **None.** PS2 kernel services are reimplemented in C++. |
| PAL support | PAL games run (e.g. Samurai Western (Europe), Viewtiful Joe (Europe), Altered Beast (Europe), Urban Reign (Europe)); PAL video mode is handled by GS registers. |
| Game-specific code | Claimed zero for 35 titles; fixes go into the generic runtime. |
| Proven | God of War II played start-to-finish; 55 games tested, 35 out of the box; 54/55 `ps2autotests` programs match real console output. |
| Reusable | **Everything** — recompiler, runtime, builder app, tests. |
| Limitations | Slower than PCSX2 in the author's benchmarks; early stage; some titles black-screen. Derived from `ps2-web-recomp`. |

Source inspected: `recomp/elf.cpp` (little-endian ELF32 loader), `recomp/main.cpp`
(entry discovery + `overlays/` handling), `scripts/port.sh` (6-stage pipeline), `scripts/setup.sh`
(pinned wgpu-native v29.0.1.1, SDL2 2.32.10, DXC), `docs/disc-boot.md`.

### 1.2 `snuri00/ps2-web-recomp` — upstream lineage

MIT. Compiles EE to C++/WebAssembly, draws GS with WebGPU compute, interprets the disc's
IRX modules on the IOP, compiles VU1 microprograms ahead of time, reimplements sound and
movies. This is the technical ancestor of 1.1; no separate integration is needed because
1.1 already carries the code.

### 1.3 `ran-j/PS2Recomp` — rejected as foundation

| Property | Finding |
|---|---|
| Status | Created 2025-04-12, ~170 commits; active but experimental. |
| Licence | **GPL-3.0** — incompatible with a proprietary-friendly builder distribution. |
| Method | Static R5900 → C++ (`addiu $r4,$r4,0x20` → `ctx->r4 = ADD32(...)`), MMI and VU0 macro mode. |
| Modules | `ps2xAnalyzer` (ELF/function scan → TOML), `ps2xRecomp`, `ps2xRuntime`, `ps2xIOP` (R3000A IRX + HLE). |
| Requires | Ghidra script to export function maps for stripped retail games. |
| Proven | No playable game at inspection time; Resident Evil Code Veronica reaches memory-card init in a third-party project (`Gui-Tora/dmc-recomp`). Recompendium: "CPU works, GS/VU1/DMA stubbed". |
| Reusable | Ideas only (TOML config shape, Ghidra function export). |

Gigazine and Time Extension coverage (Jan 2026) confirm the "experimental, no playable
games yet" state. Third-party ports based on it (e.g. `KIexster/god-of-war-recomp`) show
promise but require extensive per-game runtime work.

### 1.4 `luisbraganca/ps2n` — promising alternative, not selected

MIT-style static recompiler, 48 commits, created 2026-10-28. Single instruction tables
(`r5900_ops.inc`, `r5900_sem.inc`) shared by decoder/disassembler/assembler; semantics in
runtime headers.claims 007 Agent Under Fire and RE Code Veronica X reach in-game states.
No game fully playable. Selected project has far broader validation.

### 1.5 `open-goal/jak-project` — rejected

Full decompilation of Naughty Dog GOAL code (a custom LISP) into x86-64. Jak 1 polished,
Jak 2 beta, Jak 3 WIP. Supports PAL/NTSC/NTSC-J retail discs. Requires years of manual
type annotations and a bespoke GOAL compiler; the technique does not transfer to a
Radical Entertainment C++/Pure3D title. Useful as proof that native ports can be excellent,
not as a tool for this project.

### 1.6 `PCSX2` — reference implementation, deliberately not shipped

Mature dynamic recompiler/interpreter with GS, VU, SPU2, IOP and BIOS support. Explicitly
**not** embedded: the objective is a native program, not an emulator wrapper. PCSX2 sources
and wiki are used as documentation for GS registers, timing and the game's compatibility
notes. PCSX2's wiki entry for Road Rage notes "software rendering only" and a widescreen
patch — a warning to verify GS output carefully.

### 1.7 Other projects surveyed

- `ps2autotests` (unknownbrackets): 55-program conformance suite used by 1.1; 54/55 match.
- `glampert/ps2-re-tools`: EE ELF, VU microcode, VIF/DMA/GIF packet RE toolkit; useful if
  manual DVP overlay decoding becomes necessary.
- `Gui-Tora/dmc-recomp`: real PAL (SLES_503.58) bring-up using PS2Recomp; documents blockers
  (entry-point boundaries, CD-read IOP service, PSS streaming) that we should watch for.
- Recompendium/Recompedia catalogues: 40+ PS2 recomps, 15 decompilations; most experimental.
  Notable working native titles: Def Jam FFNY, Guitar Hero II, God of War I/II, GT4,
  Midnight Club II, Ratchet & Clank, Twisted Metal: Black, Urban Reign.
- Decompilation projects (`ssx3-decomp`, `NocturneDecomp`, `TheMoonPeople`, `rac1-native`)
  confirm the "readable C++ port + small hardware layer" pattern works but is manual.

## 2. Architecture comparison

| | A. Static recompilation | B. Hybrid (recommended) | C. Dynamic recompilation | D. Full decompilation |
|---|---|---|---|---|
| EE code | Native C++ ahead of time | Native C++ ahead of time; runtime discovers missed windows | JIT at runtime | Hand-written C++ |
| Hardware | Must be implemented | Reused native runtime (GS/VU/IOP/SPU2) | Emulated hardware | Native replacements per game |
| Standalone EXE | Yes | Yes | Usually no (emulator) | Yes |
| Effort for Road Rage | Very high from scratch | **Moderate** (upstream exists) | Low but wrong goal | Years of manual work |
| Accuracy risk | High (instruction coverage) | Low (tested baseline) | Medium | High during reconstruction |
| PAL support | Must implement | Present | Present | Must reimplement |

**Recommendation: B — hybrid recompilation built on `ps2-native-recomp`.** It is the only
option that already produces standalone Windows executables from a user-supplied ISO,
requires no BIOS, and has a measured track record on retail PAL discs. It also satisfies
"do not embed PCSX2": the EE code really is translated to C++ and compiled. The "hybrid"
part is the native hardware runtime — reused, not an emulator process.

## 3. Major technical risks

1. **Unseen code paths.** Static analysis cannot see all code in a stripped game with
   overlays and computed jumps. Mitigation: upstream's exploratory runs + `overlays/`
   capture + `entries.txt`, then rebuild.
2. **VU microcode.** Road Rage ships 13 KB of `.vutext`. Baseline build interprets VUs;
   exploratory runs should compile them ahead of time. If Pure3D uses unusual VU1
   features, native VU translation may need fixes.
3. **GS rendering.** PCSX2 marks the game software-rendering-only. If D3D12 output is wrong,
   the GS renderer may need a targeted fix.
4. **RADSound.** Proprietary IRX runs, but host audio streaming/music may need work.
5. **Memory card.** Game explicitly supports slot 1/2 saves and formatted 8 MB cards;
   native memcard emulation must accept the game's format checks.
6. **Timing.** PAL 50 Hz behaviour and PSS movie sync must be preserved.
7. **Licensing.** Upstream is MIT; generated C++ is a translation of user-owned game code
   and must stay on the user's machine. No ISO, ELF, IRX or generated code is committed.

## 4. Sources

- GitHub repositories and raw READMEs listed above (inspected 2026-11-20).
- `recompendium.com/en/consola/ps2`, `recompedia.com/platform/ps2`.
- PCSX2 wiki: The Simpsons: Road Rage; redump.org disc entries 4526 and 22578.
- `psi-rockin.github.io/ps2tek`, `copetti.org/writings/consoles/playstation-2/`
  for R5900/GS/VU reference.
