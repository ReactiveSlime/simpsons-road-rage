# Progress and evidence

Date of measured work: 2026-11-20. Every claim below is backed by a file in
`analysis/`, `build/` or `docs/` in this repository. Captured frames are kept
git-ignored because they contain copyrighted game imagery.

## Milestone summary

| # | Milestone | Status | Evidence |
|---|---|---|---|
| 1 | Workspace audit; no prior work overwritten | Done | `BASELINE_REPORT.md` |
| 2 | Exact disc identity SLES-505.40 (English PAL) | Done | `analysis/disc_inventory.json`, `analysis/iso_validation.json` |
| 3 | Toolchain bootstrap (upstream, wgpu, SDL2, DXC, clang++) | Done | `build/upstream_setup.log`, `TOOLCHAIN.md` |
| 4 | Static EE recompilation and native EXE | Done | `build/port_baseline.log`, 136 C++ units |
| 5 | Baseline boot: IOP reboot, 10 IRX, RADSound, D3D12 | Done | `analysis/run_baseline.log` |
| 6 | Exploratory VU discovery: 42 VU1 programs | Done | `build/port_explore.log`, `analysis/run_explored_full.log` |
| 7 | Title screen reached and input path validated | Done | `analysis/run_menu.log`, `analysis/frame_stats_menu.csv`, OCR `PRESS START` |
| 8 | Main menu reached | Done | OCR of frames 2500 and 2800 (`LOAD`, `Start a new game`, `Road Rage`, `Sunday Drive`, `Mission Mode`, `Options`) |
| 9 | Driver select, area select, loading and 3D gameplay reached | Done | `analysis/run_play.log`, `analysis/frame_stats_play.csv`, OCR/ASCII of `analysis/shots_play/` |
| 10 | Reproducible scripts and regression tests | Done | `scripts/*.ps1`, `tests/test_tools.py`, `scripts/test.ps1` |
| 11 | Audio verification | Not done | No loopback capture yet |
| 12 | Memory-card save/load | Not done | Game displays "No memory card" warning; saved games not exercised |
| 13 | Full playthrough / two-player | Not done | Out of scope for this milestone |
| 14 | Clean-machine distribution test | Not done | Package script written, not executed on another PC |
| 15 | Live keyboard/mouse input and focus fix | Done | `analysis/kbm_evidence.txt`, `analysis/kbm_stderr.log`, `tools/kbm_probe.ps1`, `patches/0001-windows-kbm-focus.patch` |

## Commands used for the measured build

From the upstream root inside Git Bash, with llvm-mingw on `PATH` and `CXX` set
to that `clang++.exe`:

```bash
# Baseline (no code discovery)
bash scripts/port.sh roadrage "/d/Games/RECOMPS/WIP_GAMES/simpson_road_rage/Simpsons Road Rage PS2 PAL.iso" --native-only --no-explore

# Exploratory build (code discovery + VU1 recording)
bash scripts/port.sh roadrage "/d/Games/RECOMPS/WIP_GAMES/simpson_road_rage/Simpsons Road Rage PS2 PAL.iso" --native-only --frames 3600 --rounds 6
```

The equivalent project-level command is now:

```powershell
./scripts/build.ps1                         # exploration on by default
./scripts/build.ps1 -NoExplore              # baseline-only rebuild
```

## How menu and gameplay were confirmed

The assistant cannot view images directly, so text evidence was produced without
displaying or committing copyrighted art:

1. `tools/frame_stats.py` produced numeric summaries for every captured frame.
2. `tools/ascii_frame.py` rendered headless luminance previews to the terminal.
3. `tools/ocr_frame.ps1` used the host's installed Windows OCR engine (`en-GB`)
   on upscaled copies of the captured frames. The upscaled images stay under
   git-ignored `analysis/shots_*/upscaled/`.

Key observations:

- The title screen appears around frame 2000. OCR reads `PRESS START` plus a
  stylised `ROAD RAGE` logo. The first long run pressed Start at frame 1200,
  before the prompt existed, so the stable title image was expected. Pressing
  Start at frame 1800 advances correctly.
- Frame 2500 OCR: `LOAD`, `No memory card ...`, `Start a new game`, `Retry`,
  `Accept`. Frame 2800 OCR: `Road Rage`, `Sunday Drive`, `Mission Mode`,
  `Options` — the main menu.
- Frame 3200/3400 OCR: `PLAYER 1 DRIVER`, `Homer`, `Family Sedan`.
- Frame 3600 OCR: area list including `Evergreen Terrace`, `Entertainment
  District`, `Springfield Dam`, `Nuclear Power Plant`, `Downtown`,
  `Springfield Mountains`.
- Frames 3800–4800 read `Loading...`.
- Frames 5200–6000 have a different signature (nonblack fraction ~0.94–1.0,
  tens of thousands of changing pixels) and their ASCII previews show a road
  scene with perspective, buildings and vehicles. This is the first direct
  evidence of 3D gameplay under the native runtime.
- `analysis/run_play.log` ends with `stopped after 6000 frames, 35390219142
  cycles: frame limit reached`; no crash, unsupported instruction or fault is
  recorded. It logs 100,018,449 GS primitives and continuous GIF/DMA/VIF
  traffic.

## Scripted input sequence

The runner's button names are defined in upstream
`runtime/src/system.cpp::parse_press`: `select`, `l3`, `r3`, `start`, `up`,
`right`, `down`, `left`, `l2`, `r2`, `l1`, `r1`, `triangle`, `circle`, `cross`,
`square`, plus stick aliases `lup`, `ldown`, `lleft`, `lright`. Syntax is
`FRAME:BUTTON+BUTTON:FRAMES`.

Working boot-to-gameplay sequence:

```
1800:start  2100:cross  2400:start  2700:cross
3100:cross  3400:cross  3700:cross  4000:start
4300:cross  4600:cross  4900:start  5200:cross
5500:cross
```

This sequence is the default in `scripts/build.ps1` and
`scripts/verify_runtime.ps1`.

## Live keyboard/mouse

`tools/kbm_probe.ps1` launches the windowed EXE, enables `PS2_PAD_LOG=1`, and
injects real Win32 scan codes with `SendInput`. Its `-NoFocus` mode deliberately
skips all focus help from the probe, so it also tests the runner's own Windows
focus patch. Full bindings and `keys.ini` behaviour are in `docs/INPUT.md`.

Evidence from the final `-NoFocus` run:

- The runner acquired the SDL window focus itself.
- `Esc` reached port 1 as `buttons 0008 start` at frame 2118, released at 2124.
- `Down` reached port 1 as `buttons 0040 down` at frame 2814, released at 2820.
- The run exited 0 after 3,500 frames with no unsupported-input report.
- The generated `keys.ini` had zero parse problems and upstream defaults.

The concise findings are committed as `analysis/kbm_evidence.txt`; the raw pad
log is `analysis/kbm_stderr.log`. Windowed D3D12 output cannot be read back by
GDI capture, so the visual companion run is `analysis/shots_kbm_headless/`.

## Tests

`python -m unittest discover -s tests -v` passes 5 tests covering synthetic ISO
identity parsing, wrong-variant rejection, ELF structure parsing and frame
statistics. `scripts/test.ps1` also validates the real ISO when given `-Iso`.
