# Building

## One-time setup

1. Install Git for Windows, Python 3 with Pillow (`python -m pip install pillow`),
   and llvm-mingw UCRT:

   ```powershell
   winget install --id MartinStorsjo.LLVM-MinGW.UCRT -e
   ```

2. From this repository root, run:

   ```powershell
   ./scripts/setup.ps1
   ```

   This clones the pinned upstream at
   `third_party/ps2-native-recomp/`, checks out commit
   `74912bd8e57c327a02242cde4df36f12e986a2c0`, downloads wgpu-native, SDL2 and
   DXC, and builds `eerecomp`/`vurecomp`. Evidence is written to
   `build/upstream_setup.log`.

3. Check the tools before a full build:

   ```powershell
   ./scripts/test.ps1
   ```

## Build the native game

Place the legally owned `Simpsons Road Rage PS2 PAL.iso` in the repository root,
or pass another path with `-Iso`. Then:

```powershell
./scripts/build.ps1
```

By default this:

1. validates the exact SLES-505.40 identity and writes
   `analysis/iso_validation.json` and `build/validate_iso.log`;
2. runs upstream's six-stage `port.sh` with exploration enabled (6,000 frames,
   6 rounds, menu-aware `--press` sequence);
3. writes `build/port_explore.log` and produces
   `third_party/ps2-native-recomp/build/native-roadrage/ps2run.exe`.

For a quick baseline build without code discovery:

```powershell
./scripts/build.ps1 -NoExplore
```

This writes `build/port_baseline.log`. For a completely fresh build:

```powershell
./scripts/build.ps1 -Clean
```

`-Clean` deletes only the generated game caches under the pinned upstream
checkout, never the source ISO. Use `-SkipValidation` only for debugging.

## Run from the build tree

From `third_party/ps2-native-recomp/`:

```powershell
.\build\native-roadrage\ps2run.exe --disc games/roadrage/disc.iso --game-dir games/roadrage --window
```

Useful runner options:

- `--fullscreen` instead of `--window`
- `--frames N` for a bounded headless run
- `--press FRAME:BUTTON[:FRAMES]` for deterministic input
- `--memcard card.ps2` for memory-card tests
- `--trace-io`, `--trace-iop`, `--trace-threads` for diagnostics
- `PS2_GPU_BACKEND=vulkan` to try Vulkan instead of D3D12

## Package a self-contained folder

```powershell
./scripts/package.ps1
```

This creates `dist/roadrage/` containing `ps2run.exe`, `SDL2.dll`,
`dxcompiler.dll`, `dxil.dll`, the user's `game/disc.iso`, the recompiler caches,
`PLAY.cmd`, `README.txt` and `SHA256SUMS.txt`. No BIOS or PCSX2 process is
involved. The package is for the owner of the disc; do not redistribute the ISO
or extracted data.

Use `-SkipIsoCopy` during development if the game folder already has a disc
image mounted elsewhere.

## Reproduce the evidence run

```powershell
./scripts/verify_runtime.ps1
```

It runs 6,000 frames with the menu sequence, captures frames every 200 refreshes,
writes `analysis/run_verify.log` and `analysis/frame_stats_verify.csv`, and
optionally writes Windows OCR output to `analysis/runtime_ocr.txt` (use
`-SkipOcr` on machines without the `en-GB` OCR pack).

## Troubleshooting

| Symptom | Action |
|---|---|
| `no clang C++ compiler with <format> found` | Install llvm-mingw UCRT or set `PS2_CXX`; see `TOOLCHAIN.md`. |
| `ISO validation failed` | The image is not the exact SLES-505.40 release; check `tools/validate_iso.py` output. |
| `Upstream tools are missing` | Run `./scripts/setup.ps1`. |
| No frames are captured | Create the frames directory first; upstream's `--frames-dir` fails silently if it does not exist. Our scripts create it. |
| Black frames only | The first ~1800 frames include fades/FMVs; use the menu press sequence and capture to 6,000 frames. |
| Game says no memory card | Expected with no `--memcard`; choose `Accept` to start a new game. |
