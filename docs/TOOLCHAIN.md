# Toolchain

All commands below are for Windows x64. The host used for the measured build ran
Windows with an NVIDIA GeForce RTX 2080 SUPER and Direct3D 12.

## Required software

| Tool | Version used | Purpose |
|---|---|---|
| Git for Windows / Git Bash | bash 5.x (Git for Windows) | runs upstream `setup.sh` and `port.sh` |
| llvm-mingw UCRT | `llvm-mingw-20261020-ucrt-x86_64`, Clang 23.1.4 | C++20 compiler with the vector builtins upstream requires |
| Python | 3.x with Pillow 12.3.0 | ISO/ELF analysis, frame statistics, synthetic-image tests |
| PowerShell | 7.x (5.1 also works for the OCR helper) | orchestration scripts |
| Windows OCR | `en-GB` language pack, installed by default on this host | optional headless reading of captured menu text |
| Network | one-time | downloads wgpu-native v29.0.1.1, SDL2 2.32.10, DXC v1.9.2609 |

Install llvm-mingw with:

```powershell
winget install --id MartinStorsjo.LLVM-MinGW.UCRT -e
```

`scripts/common.ps1` discovers Git Bash and `clang++.exe` automatically. Set
`PS2_CXX` to a different `clang++.exe` if the auto-detected compiler is wrong.

## Pinned upstream

- Repository: <https://github.com/exoteric33/ps2-native-recomp>
- Commit: `74912bd8e57c327a02242cde4df36f12e986a2c0`
- Licence: MIT
- Role: EE static recompiler, native C++ hardware runtime, D3D12/Vulkan renderer,
  SDL2 host, IOP/IRX execution, VU compiler, overlay/entry discovery.

The checkout lives at `third_party/ps2-native-recomp/` and is git-ignored. It is
never vendored into commits; `scripts/setup.ps1` recreates it.

## Environment passed to upstream

`scripts/setup.ps1` and `scripts/build.ps1` set:

- `PATH` prefixed with the llvm-mingw `bin` directory, so `cmake`, `ninja` and
  `clang++` resolve while running under Git Bash;
- `CXX` to the MSYS-style path returned by `cygpath -u`, e.g.
  `/c/Users/.../llvm-mingw-.../bin/clang++.exe`;
- `EMSDK` is left to upstream's default because the build uses `--native-only`.

PS2_* switches are intentionally left unset. The runtime therefore uses its
defaults: PAL from the disc, D3D12 on Windows, DXC shaders, AVX2 auto-detected
with `-ffp-contract=off` for deterministic vector-unit arithmetic.

## Generated artefacts

| Path | Description | Committed? |
|---|---|---|
| `third_party/ps2-native-recomp/generated/roadrage/` | recompiled EE C++ | No |
| `third_party/ps2-native-recomp/games/roadrage/` | disc image, extracted boots, VU/overlay caches | No |
| `third_party/ps2-native-recomp/build/native-roadrage/` | native executable and DLLs | No |
| `analysis/shots_*/` | captured frames (game imagery) | No |
| `analysis/*.log`, `analysis/*.csv`, `analysis/*.json` | text evidence | Yes |
| `build/*.log` | command logs | Yes |

## Verification of the compiler choice

The baseline build log records 136 generated C++ translation units and a native
`ps2run.exe` of roughly 46 MB. A wrong compiler normally fails earlier in
`scripts/cxx.sh` with a message about missing `<format>` or vector builtins.
