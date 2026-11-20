# The Simpsons: Road Rage — native Windows x64 port

This repository builds a standalone Windows executable from a legally supplied copy of
**The Simpsons: Road Rage (SLES-505.40, English PAL Europe)**. The EE code is statically
recompiled to C++ and runs on a native C++ PS2 hardware runtime with D3D12 or Vulkan.
**No PCSX2 process, emulator wrapper or BIOS image is used.**

## Requirements

- Windows x64
- Git for Windows, including Git Bash
- Python 3
- llvm-mingw UCRT: `winget install --id MartinStorsjo.LLVM-MinGW.UCRT -e`
- Network access once, to download the pinned upstream toolchain dependencies

## Quick start

```powershell
python -m pip install -r requirements.txt
./scripts/setup.ps1
./scripts/test.ps1
./scripts/build.ps1
```

Put your own `Simpsons Road Rage PS2 PAL.iso` in the repository root, or pass its path with
`-Iso`. The build creates `third_party/ps2-native-recomp/build/native-roadrage/ps2run.exe`.

To run it from the upstream root:

```powershell
cd third_party/ps2-native-recomp
.\build\native-roadrage\ps2run.exe --disc games/roadrage/disc.iso --game-dir games/roadrage --window
```

Delete any stale `keys.ini` before the first launch so the patched Road Rage defaults are
used. See `docs/BUILDING.md` for build options and `docs/TOOLCHAIN.md` for pinned versions.

## Controls

`W`/`Enter`/keypad `Enter` accelerate, `S`/`Down` stop or reverse, `A`/`D` and the arrow
keys steer, `Space`/left mouse is the hand brake, `H`/middle mouse is the horn, left/right
`Shift` are the cheat shoulder buttons, `C`/right mouse looks back, `R`/`Backspace` resets,
and `Esc` pauses.

## Known issues

- Intro videos can appear frozen. Press `Enter` to skip and continue.
- Play has been observed at roughly 20 fps. PAL timing is unchanged; no FPS or widescreen
  patch is applied.

## Documentation

- `docs/BUILDING.md` — setup, build, run and troubleshooting
- `docs/TOOLCHAIN.md` — pinned dependencies and generated outputs
- `third_party/README.md` — pinned upstream checkout

## Licence

The original scripts, tools, docs and configuration in this repository are MIT licensed;
see `LICENSE`. The game, its assets and the pinned upstream `ps2-native-recomp` project are
not covered by that licence.

## Legal note

No copyrighted disc image, extracted asset, boot ELF, IRX module, generated C++ translation
or captured game image is tracked here. Build outputs and local logs are ignored by Git.
