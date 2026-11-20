# Building

All commands are run from the repository root in PowerShell on Windows x64.

## One-time setup

Install Git for Windows and Python 3, then install the pinned Python test dependency and
llvm-mingw UCRT:

```powershell
python -m pip install -r requirements.txt
winget install --id MartinStorsjo.LLVM-MinGW.UCRT -e
```

Then run:

```powershell
./scripts/setup.ps1
```

This clones the pinned upstream into `third_party/ps2-native-recomp/`, checks out commit
`74912bd8e57c327a02242cde4df36f12e986a2c0`, downloads wgpu-native, SDL2 and DXC, builds
`eerecomp`/`vurecomp`, and applies the patches under `patches/` idempotently. Logs are
written to the ignored `build/` directory.

Check the local tools before a full build:

```powershell
./scripts/test.ps1
```

## Build the native game

Place your legally owned `Simpsons Road Rage PS2 PAL.iso` in the repository root, or pass
another path with `-Iso`. Then:

```powershell
./scripts/build.ps1
```

By default this validates the exact SLES-505.40 identity, writes `build/iso_validation.json`
and `build/validate_iso.log`, runs upstream's exploratory `port.sh` pass (6,000 frames,
6 rounds, menu-aware input sequence), and produces:

```text
third_party/ps2-native-recomp/build/native-roadrage/ps2run.exe
```

Useful variants:

```powershell
./scripts/build.ps1 -NoExplore              # baseline recompile without code discovery
./scripts/build.ps1 -NoExplore -SkipValidation  # quick rebuild from an existing ISO setup
./scripts/build.ps1 -Clean                  # delete generated caches and rebuild
```

`-Clean` removes only generated upstream caches, never the source ISO. All build logs and
validation JSON stay in the ignored `build/` directory.

## Run

From `third_party/ps2-native-recomp/`:

```powershell
.\build\native-roadrage\ps2run.exe --disc games/roadrage/disc.iso --game-dir games/roadrage --window
```

Useful runner options:

- `--fullscreen` instead of `--window`
- `--frames N` for a bounded run
- `--press FRAME:BUTTON[:FRAMES]` for deterministic input
- `--memcard card.ps2` for memory-card tests
- `PS2_GPU_BACKEND=vulkan` to try Vulkan instead of D3D12

Delete any stale `keys.ini` before the first launch. The patched defaults are:

- Accelerate: `W`, `Enter`, keypad `Enter`
- Stop/reverse: `S`, `Down`
- Steer: `A`, `D`, `Left`, `Right`
- Hand brake: `Space`, left mouse
- Horn / L1: `H`, middle mouse
- Cheat shoulders: left `Shift` = L1, right `Shift` = R1
- Look back: `C`, right mouse
- Reset: `R`, `Backspace`
- Pause: `Esc`

## Troubleshooting

| Symptom | Action |
|---|---|
| `no clang C++ compiler with <format> found` | Install llvm-mingw UCRT or set `PS2_CXX`; see `TOOLCHAIN.md`. |
| `ISO validation failed` | The image is not the exact SLES-505.40 release; check `tools/validate_iso.py` output. |
| `Upstream tools are missing` | Run `./scripts/setup.ps1`. |
| Keyboard/mouse does nothing | Click the game window once. Delete stale `keys.ini`, or rebuild so `patches/0001-windows-kbm-focus.patch` is applied. |
| Intro videos appear frozen | Press `Enter` to skip and continue. |
| Game says no memory card | Expected with no `--memcard`; choose `Accept` to start a new game. |
