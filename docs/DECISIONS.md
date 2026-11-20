# Decisions

## 1. Hybrid static recompilation on `ps2-native-recomp`

**Decision.** Translate the EE's MIPS code to C++ ahead of time with the pinned
MIT upstream, and keep its native C++ runtime for GS, VU, IOP, DMA, SIF, SPU2,
PAD and memory card.

**Why.** It is the only surveyed stack that already produces a standalone Windows
EXE from a user-supplied disc, needs no BIOS, and has a measured record on retail
PAL games. A from-scratch recompiler would duplicate tested work; an emulator
wrapper would violate the requirement. See `RESEARCH.md`.

**Rejected.** `ran-j/PS2Recomp` (GPL-3.0, stubbed GS/VU1/DMA, no playable title),
`open-goal/jak-project` (bespoke GOAL decompilation, not transferable to Pure3D),
PCSX2 as a shipped component (reference only).

## 2. Exact release: SLES-505.40 only

**Decision.** Accept only the English-only PAL Europe build with boot file
`SLES_505.40`, `VMODE = PAL`, 1,214,640 sectors, CRC32 `a48f9f41` and the hashes in
`tools/validate_iso.py`.

**Why.** The other PAL SKU, SLES-50628, has the same sector count but a different
EXE date and multilingual assets. Region confusion would invalidate every later
result. The validator rejects it and NTSC/JP builds explicitly.

## 3. No copyrighted material in git

**Decision.** Never commit the ISO, boot ELF, IRX modules, extracted RCF/DAT
assets, generated C++ translations, captured frames or the upstream checkout.

**Implementation.** `.gitignore` covers `*.iso`, `work/`, `games/`, `generated/`,
`shots/`, `analysis/shots_*/`, images, build binaries and `third_party/*/`.
Only text reports, logs and source authored here are committed. Packaging copies
game data locally from the user's own build.

## 4. Evidence-first documentation

**Decision.** Claims about compatibility require logs, numeric frame statistics,
OCR text or test results stored in the repository.

**Implementation.** `PROGRESS.md` maps each milestone to a file.
`COMPATIBILITY.md` separates verified behaviour from open risks. Benign runtime
messages are recorded instead of being silently ignored.

## 5. Text-only image verification

**Decision.** Because the assistant cannot view images directly and game art must
not be redistributed, visual checks use ASCII luminance previews, numeric
statistics and local Windows OCR on upscaled copies.

**Why.** This still produces reproducible evidence (for example `PRESS START` and
the main-menu entries) without committing copyrighted screenshots.

## 6. Reproducible orchestration

**Decision.** Put all host-specific logic in PowerShell scripts under `scripts/`,
share compiler discovery in `scripts/common.ps1`, and pin the upstream commit.

**Why.** Builds must not depend on ad-hoc environment state. `scripts/test.ps1`
runs fast structural tests plus optional full ISO validation. Build and runtime
commands are the same ones used to produce the committed evidence.

## 7. PAL timing left unchanged

**Decision.** Do not apply FPS or widescreen patches. The runtime uses the disc's
PAL settings and 50 Hz frame pacing.

**Why.** Changing timing or aspect ratio would hide correctness problems and make
comparisons with the original release unreliable. Widescreen remains an optional
runner switch for later investigation.

## 8. Scope of this milestone

**Decision.** Stop the committed baseline after reaching rendered gameplay with
scripted input; leave audio, memory-card saves, two-player mode and a full
playthrough as explicit open items.

**Why.** These need either hardware loopback capture, a prepared memory card,
human playtesting or longer runs. Recording them as unverified is more honest
than claiming a complete port without evidence.

## 9. Road Rage keyboard/mouse layout as a repo patch

**Decision.** Keep the pinned upstream checkout otherwise untouched, but add
`patches/0002-roadrage-kbm-layout.patch` to replace its generic defaults with a
driving layout in `defaults()`, `keys.ini` comments, the F1 key card and the
quick-menu action labels.

**Why.** The upstream generic map (WASD on the left stick, IJKL on the right,
Space on Cross) does not match this game's actions. The PS2 manual and control
lists give a small, fixed set of driving actions, so a game-specific default is
both more natural and still reproducible. Applying it as a patch keeps the
upstream version pinned and lets `scripts/apply_patches.ps1` reproduce the same
defaults on a clean checkout. See `INPUT.md` for the research and evidence.

## 10. Publishable repository hygiene

**Decision.** Add `.recomp.json`, an MIT `LICENSE` for original project files,
a pinned `requirements.txt`, and `docs/PUBLISHING.md`; rename the branch to
`main`; and replace machine-specific paths and account names in committed
evidence with portable placeholders.

**Why.** The repository can then be pushed to any public Git host without
leaking local paths or copyrighted game data, and recomp.board or another
reader can identify the project from the root metadata file. The MIT licence
covers only material authored here; the game, its assets and upstream
`ps2-native-recomp` keep their own terms.

**Implementation.** `docs/PUBLISHING.md` records the pre-upload checks and
remote/push commands. The repository was then pushed to
`https://github.com/ReactiveSlime/simpsons-road-rage` on branch `main`.

## 11. Runtime-only release asset

**Decision.** Publish a GitHub Release whose attached ZIP contains only
`ps2run.exe`, the three required DLLs, `PLAY.cmd`, a README, `SHA256SUMS.txt`
and licence texts. GitHub's automatic source archive covers the source code;
no separate source ZIP is attached.

**Why.** The runner needs the user's own disc and locally generated caches to
do anything useful, so shipping the ISO or extracted data would add no value
and would violate the no-copyrighted-material rule. A clearly labelled
runtime-only asset avoids implying that a complete playable game is being
redistributed.

**Implementation.** `scripts/package_runtime_release.ps1` stages only an
allow-listed set of files, fails if anything else appears, writes checksums,
and produces `dist/roadrage-runtime-<version>.zip`. `docs/PUBLISHING.md`
records the tag and `gh release create` commands.
