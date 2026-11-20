# Publishing this repository

The repository is initialised on branch `main`, pushed to GitHub and tracked by
`origin`. This page records the checklist used before the first push and the
procedure for later releases.

## Pre-upload checklist

- [x] Working tree is clean and all milestones are committed.
- [x] `./scripts/test.ps1` passes (5 structural regression tests).
- [x] Only text source, reports, logs, patches and evidence are tracked.
- [x] `*.iso`, `work/`, `games/`, generated C++, captured frames, binaries and
      the upstream checkout are ignored by `.gitignore`.
- [x] Machine-specific absolute paths, account names and audio-device names
      were replaced with placeholders in committed evidence.
- [x] `.recomp.json` describes this project to recomp.board and other readers.
- [x] `LICENSE` covers the original scripts, tools, docs and configuration.
- [x] `requirements.txt` pins the Python test dependency.

Confirm the tracked file list contains no game content:

```powershell
git ls-files
```

Confirm no large/binary artefacts slipped in:

```powershell
git ls-files | Select-String -Pattern '\.(iso|bin|exe|dll|pdb|png|ppm|ps2|zip)$'
```

That command should print nothing. The 2.5 GB ISO is intentionally left in the
working directory and ignored.

## Add a remote and push

Create an **empty** remote repository first. Do not let the host add a README,
`LICENSE` or `.gitignore`, or the first push will conflict with files already
committed here.

```powershell
git remote add origin https://<host>/<owner>/<repository>.git
git push -u origin main
```

If a remote already exists, replace `add` with `set-url`:

```powershell
git remote set-url origin https://<host>/<owner>/<repository>.git
git push -u origin main
```

After pushing, check that the default branch is `main`. A public repository on
the default branch lets sites such as recomp.board read `.recomp.json`; until
then the file is documentation only.

## Runtime-only release ZIP

`scripts/package_runtime_release.ps1` builds a ZIP with only the standalone
runner binaries, a launch script, a README, checksums and licence texts:

```text
ps2run.exe  SDL2.dll  dxcompiler.dll  dxil.dll
PLAY.cmd  README.txt  SHA256SUMS.txt
LICENSE-project.txt  LICENSE-upstream.txt
```

It never includes the ISO, extracted game data, generated C++, recompiler
caches, captured imagery, a BIOS or PCSX2. Users supply their own disc and
generate its caches with the source build as described in the ZIP's README.

```powershell
./scripts/package_runtime_release.ps1 -Version v0.1.0
git tag -a v0.1.0 -m "Runtime-only v0.1.0"
git push origin v0.1.0
gh release create v0.1.0 .\dist\roadrage-runtime-v0.1.0.zip `
  --title "v0.1.0 - runtime only" `
  --notes "Runtime binaries only; GitHub also generates the source archive. No game data is included."
```

## What must never be uploaded

- The ISO, any extracted game files, boot ELF or IRX modules.
- Generated C++ translations or recompiler caches.
- Captured frames, recordings, PPM/PNG images or OCR source images.
- BIOS images, PCSX2 installations or any emulator binary.
- `third_party/ps2-native-recomp/`: `scripts/setup.ps1` clones it again at the
  pinned commit.

`scripts/package.ps1` assembles a local playable folder for the disc owner.
That folder is for personal use and is not part of the Git repository.

## Licence scope

`LICENSE` applies only to the original material authored in this repository
(scripts, tools, docs, patches, configuration and tests). The game itself,
its assets and the upstream `ps2-native-recomp` project remain under their
respective owners' terms.
