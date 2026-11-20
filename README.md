# The Simpsons: Road Rage — native Windows x64 port

This repository builds a standalone Windows executable from a legally supplied copy of
**The Simpsons: Road Rage (SLES-505.40, English PAL Europe)**. The game's EE code is
statically recompiled to C++ and runs on a native C++ PS2 hardware runtime with D3D12
or Vulkan. **No PCSX2 process, emulator wrapper or BIOS image is used.**

Status: the native build boots, reaches the title screen and main menu, loads a level,
renders 3D gameplay, and accepts live keyboard/mouse input. Audio, memory-card saves,
two-player mode and a full playthrough remain unverified. See `docs/PROGRESS.md` and
`docs/COMPATIBILITY.md` for evidence and open items.

## Quick start (Windows x64)

```powershell
python -m pip install -r requirements.txt   # Python test dependency
./scripts/setup.ps1        # clone pinned upstream, install native deps, build tools
./scripts/test.ps1         # structural regression tests
./scripts/build.ps1        # validate ISO, recompile, explore, build ps2run.exe
./scripts/package.ps1      # create dist/roadrage with PLAY.cmd (local use)
./scripts/package_runtime_release.ps1  # runtime-only ZIP for GitHub Releases
```

Put your own `Simpsons Road Rage PS2 PAL.iso` in the repository root, or pass `-Iso`.
Full instructions are in `docs/BUILDING.md`; toolchain details are in
`docs/TOOLCHAIN.md`.

## Documentation

- `docs/RESEARCH.md` — ecosystem survey and why this architecture was chosen
- `docs/DECISIONS.md` — explicit project decisions and rejected alternatives
- `docs/BUILDING.md` — reproducible build, run and packaging commands
- `docs/TOOLCHAIN.md` — pinned versions and environment
- `docs/GAME_ANALYSIS.md` — disc, ELF, engine and runtime findings
- `docs/ARCHITECTURE.md` — pipeline and layering
- `docs/BASELINE_REPORT.md` — initial workspace audit
- `docs/PROGRESS.md` — milestone evidence
- `docs/COMPATIBILITY.md` — verified, benign and unverified behaviour
- `docs/INPUT.md` — live keyboard/mouse bindings, `keys.ini` and focus fix
- `docs/PUBLISHING.md` — pre-upload checklist and remote/push commands
- `.recomp.json` — project metadata for recomp.board and other readers

## Licence

The original scripts, tools, docs, patches and configuration in this
repository are MIT licensed; see `LICENSE`. The game, its assets and the pinned
upstream `ps2-native-recomp` project are not covered by that licence.

## Legal note

No copyrighted disc image, extracted asset, boot ELF, IRX module, generated C++
translation or captured game image is committed. `scripts/package.ps1` copies those
files only from a local build made from the user's own disc. Distribution of the ISO
or derived game data remains the responsibility of the disc owner.
