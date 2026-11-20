# Toolchain

This project targets Windows x64 and uses D3D12 by default. Vulkan can be selected at run
time with `PS2_GPU_BACKEND=vulkan`.

## Required software

| Tool | Version used | Purpose |
|---|---|---|
| Git for Windows / Git Bash | bash 5.x | runs upstream `setup.sh` and `port.sh` |
| llvm-mingw UCRT | `llvm-mingw-20261020-ucrt-x86_64`, Clang 23.1.4 | C++20 compiler with the required vector builtins |
| Python | 3.x | ISO validation and structural tests; Pillow 12.3.0 is used by one synthetic-image test |
| PowerShell | 7.x (5.1 also works) | orchestration scripts |
| Network | one-time | downloads wgpu-native v29.0.1.1, SDL2 2.32.10 and DXC v1.9.2609 |

Install the compiler with:

```powershell
winget install --id MartinStorsjo.LLVM-MinGW.UCRT -e
```

`scripts/common.ps1` discovers Git Bash and `clang++.exe` automatically. Set `PS2_CXX` to a
different `clang++.exe` if auto-detection picks the wrong compiler.

## Pinned upstream

- Repository: <https://github.com/exoteric33/ps2-native-recomp>
- Commit: `74912bd8e57c327a02242cde4df36f12e986a2c0`
- Licence: MIT
- Role: EE static recompiler, native hardware runtime, D3D12/Vulkan renderer, SDL2 host,
  IOP/IRX execution, VU compiler, overlay and entry discovery.

The checkout lives at `third_party/ps2-native-recomp/` and is git-ignored. It is never
vendored into commits; `scripts/setup.ps1` recreates it.

## Environment passed to upstream

`scripts/setup.ps1` and `scripts/build.ps1` set:

- `PATH` prefixed with the llvm-mingw `bin` directory;
- `CXX` to the MSYS-style path returned by `cygpath -u`;
- `EMSDK` is left to upstream's default because the build uses `--native-only`.

PS2_* switches are intentionally left unset. The runtime therefore uses PAL from the disc,
D3D12 on Windows, DXC shaders, and AVX2 auto-detection with `-ffp-contract=off`.

## Generated outputs

All generated files are local and git-ignored:

| Path | Description |
|---|---|
| `build/` | setup/build logs and `iso_validation.json` |
| `third_party/ps2-native-recomp/generated/roadrage/` | recompiled EE C++ |
| `third_party/ps2-native-recomp/games/roadrage/` | disc image and generated caches |
| `third_party/ps2-native-recomp/build/native-roadrage/` | native executable and DLLs |

A correct compiler produces 136 recompiled EE units and a roughly 46 MB `ps2run.exe`. A
wrong compiler usually fails earlier in upstream's `scripts/cxx.sh` with a missing
`<format>` or vector-builtin error.
