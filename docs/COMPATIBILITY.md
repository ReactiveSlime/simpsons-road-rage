# Compatibility status

Scope: SLES-505.40 (English-only PAL Europe, boot file `SLES_505.40`), built with
`ps2-native-recomp` commit `74912bd8e57c327a02242cde4df36f12e986a2c0`.

## Verified working

| Area | Evidence / result |
|---|---|
| Disc validation | Exact size, sector count, PVD timestamp, `SYSTEM.CNF`, CRC32 and all hashes match the known SLES-505.40 image. |
| Boot ELF | Little-endian ELF32 EM_MIPS parsed; 136 EE translation units generated and linked. |
| PAL video | `VMODE = PAL`; runtime logged PAL GS CRT setup; 640×511 captured frames at ~50 Hz pacing. |
| Host API | Direct3D 12 on RTX 2080 SUPER with DXC shaders. |
| IOP | Reboot with `IOPRP214.IMG`; all ten IRX modules loaded, including `RADSOUND.IRX`, `PADMAN`, `MCMAN`/`MCSERV`. |
| SIF/DMA/GIF/GS/VIF | Sustained traffic and 100M+ GS primitives in the 6,000-frame gameplay run. |
| VU | 42 VU1 programs compiled ahead of time in the exploratory build. |
| Input | Scripted `start` and `cross` presses advance title → memory-card notice → main menu → driver select → area select → loading → gameplay. |
| Rendering | ASCII previews show a changing 3D road scene from frame ~5200 onward. |
| Stability | 6,000-frame run ended only because the frame limit was reached; no crash or unsupported-opcode report. |

## Known benign messages

These appear in the logs but do not stop the game:

- `open hosthost:always.rcf ... unsupported device -> -2`
- `open snfisnfile:always.rcf ... unsupported device -> -2`
- `open s.rcf ... on unsupported device` (several variants)
- IOP threads reported `not started` in the shutdown dump; this is a thread-status
  snapshot, not a boot failure.
- `PCSX2 patch files for it end in _D6490F47.pnach` is informational only; no
  patch file is applied.

## Not verified / open risks

- **Audio.** RADSound's own IRX starts and SPU2 registers are exercised, but no
  loopback capture was made. Music, engine noise and voice are unconfirmed.
- **Memory card.** The game detects no card and offers `Start a new game`/`Retry`/
  `Accept`. A blank card run with `--memcard` has not been performed, so save and
  load are unconfirmed.
- **Controller/keyboard live input.** Verification used the runner's deterministic
  `--press` injection. SDL2 gamepad and keyboard mappings were not manually
  exercised.
- **Vulkan backend.** Only D3D12 was measured.
- **Two-player / split screen**, mission completion, full playthrough.
- **Widescreen patch** from PCSX2 was not applied.
- **Performance.** No wall-clock FPS profile beyond the frame counter/pacing
  counters in the logs; 50 Hz game time was reached, but stutter was not measured.
- **Clean Windows.** `scripts/package.ps1` was written but not run on a second PC.
- **Overlays.** Upstream's runtime discovery is active; the eight DVP overlays in
  the ELF have not been manually decoded or pre-translated.

## Supported button names for scripted verification

`FRAME:BUTTON` or `FRAME:BUTTON:FRAMES`, with `+` to combine buttons. Buttons:
`select`, `l3`, `r3`, `start`, `up`, `right`, `down`, `left`, `l2`, `r2`, `l1`,
`r1`, `triangle`, `circle`, `cross`, `square`. Stick aliases: `lup`, `ldown`,
`lleft`, `lright`.

## Rejected inputs

`tools/validate_iso.py` and `scripts/build.ps1` reject anything that is not the
exact SLES-505.40 image, including SLES-50628 (multilingual PAL), SLUS-20305
(NTSC-U), Japanese releases, GameCube/Xbox/GBA builds and modified ISOs.
