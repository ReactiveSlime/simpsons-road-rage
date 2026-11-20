# Game analysis: The Simpsons: Road Rage, PlayStation 2 PAL

All facts below were measured from the user-supplied disc in this workspace on 2026-11-20.
No assets, executable bytes or proprietary code are reproduced here.

## 1. Disc identity

| Field | Value |
|---|---|
| File | `Simpsons Road Rage PS2 PAL.iso` |
| Size | 2,487,582,720 bytes (1,214,640 × 2048-byte sectors) |
| CRC32 (whole image) | `a48f9f41` |
| MD5 | `5a48aa28e65706a13e439d8c7d88af6f` |
| SHA-1 | `ac5949fe278dde9acdc52737e18e17fd3b24e6e5` |
| SHA-256 | `145cf07215352d716b6c908731d764fcab7d31393cc3e421779dbf4e76b2fb10` |
| PVD | sector 16, type 1, `CD001`, creation date `2001100913023900$` |
| `SYSTEM.CNF` | `BOOT2 = cdrom0:\SLES_505.40;1`, `VER = 1.00`, `VMODE = PAL` |
| Boot executable | `SLES_505.40`, 2,868,876 bytes |

**Variant:** this is **SLES-505.40**, the English-only PAL Europe build (EXE date
2001-10-09), not the multilingual SLES-50628 (EXE date 2001-10-29). The whole-image CRC
`a48f9f41` matches the published CRC for the English-only European release. The earlier
assumption that the sector count implied SLES-50628 was wrong: both are DVD-5 and have the
same sector count. Identity is established from `SYSTEM.CNF`, the PVD timestamp and CRC.

The first 303 bytes of the image are filled with `0x65`; this is a dumper/padding artefact,
not encryption. The image is a normal ISO-9660 DVD.

## 2. Disc structure

```
SYSTEM.CNF                         56 bytes
SLES_505.40                    2,868,876 bytes   (boot ELF)
IOPRP214.IMG                     140,945 bytes   (Sony IOP reboot image, SDK r214)
IRX/SIO2MAN.IRX                   6,161 bytes
IRX/MTAPMAN.IRX                  11,533 bytes
IRX/PADMAN.IRX                   43,861 bytes
IRX/LIBSD.IRX                    25,317 bytes
IRX/SDRDRV.IRX                    9,081 bytes
IRX/RADSOUND.IRX                 17,478 bytes    (Radical proprietary sound server)
IRX/MCMAN.IRX                    82,405 bytes
IRX/MCSERV.IRX                    6,649 bytes
IRX/USBD.IRX                     30,317 bytes
IRX/LGDEV.IRX                    52,885 bytes
TYP/TIBLD.TYP                    64,896 bytes
MOVIES/PAL/FRONTEND.PSS       28,442,628 bytes
MOVIES/PAL/RADLOGO.PSS         3,096,580 bytes
MOVIES/PAL/ROADRAGE.PSS        4,227,076 bytes
ART/DATA1.DAT              1,073,676,288 bytes
ART/DATA2.DAT              1,073,676,288 bytes
ART/DEST/DEST0..5.RCF        (level destination data)
ART/GUI/*.RCF               (frontend images, per language E/F/G/I/S)
ART/STECHNG.RCF               104,884,224 bytes
SOUND/MUSIC/MUSIC.RCF          79,325,184 bytes
SOUND/DIALOG/ENGLISH/DIALOG.RCF 73,723,904 bytes
SOUND/SOUNDFX/**/*.RCF
LOADING.RCF, NIS.RCF, ALWAYS.RCF
```

70 directory entries in total. The two 1 GiB `DATA*.DAT` files hold the Pure3D world data.

## 3. Executable structure (`SLES_505.40`)

| Field | Value |
|---|---|
| Format | ELF32, **little-endian**, EM_MIPS (8), ET_EXEC |
| Flags | `0x20924001` |
| Entry point | `0x00100008` |
| Segments | 1 × PT_LOAD: vaddr `0x00100000`, file offset `0x1000`, filesz `2,849,756`, memsz `3,797,108`, flags RWE |
| Sections | 22 |
| Symbols | **stripped** (no `.symtab`) |

Key sections:

| Section | Address | Size | Meaning |
|---|---|---|---|
| `.text` | `0x100000` | 2,222,720 | EE code (~555,680 R5900 instructions) |
| `.vutext` | `0x31EA80` | 13,392 | VU microprograms |
| `.data` | `0x321F00` | 304,420 | initialised data |
| `.rodata` | `0x36C480` | 297,545 | strings / tables |
| `.gcc_except_table` | `0x3B4F00` | 11,484 | **C++ exceptions** |
| `.sbss` | `0x3B7C00` | 1,520 | small BSS |
| `.bss` | `0x3B8200` | 945,780 | BSS |
| `.DVP.ovlytab` | — | 96 | eight 12-byte overlay records |
| `.DVP.ovlystrtab` | — | 300 | overlay names |

The presence of `.gcc_except_table` and C++ RTTI names in `.rodata`
(`Q210Scenegraph10Scenegraph`, `Q212tLoadManager9AsyncDone`, `CMemoryCardManager`, …)
confirms a C++ codebase compiled with GCC-family tools.

### Overlays

`.DVP.ovlystrtab` names eight overlays:

```
.DVP.overlay..0x0.3359297555.25.0
.DVP.overlay..unknvma.552293723.383.1
.DVP.overlay..unknvma.552293723.714.2
.DVP.overlay..unknvma.552293723.1104.3
.DVP.overlay..unknvma.552293723.1466.4
.DVP.overlay..unknvma.1104576859.298.5
.DVP.overlay..unknvma.1104576859.695.6
.DVP.overlay..0x0.123400595.13.0
```

`.DVP.ovlytab` records (decoded little-endian, 12 bytes each):

```
(1,   0x31EA90, 0x0000), (0x23, 0x31F298, 0x0800),
(0x49, 0x31FAA0, 0x1000), (0x6F, 0x3202A8, 0x1800),
(0x96, 0x320AB0, 0x2000), (0xBD, 0x3212B8, 0x2800),
(0xE4, 0x321AC0, 0x3000), (0x10B, 0x321D20, 0x0000)
```

The overlay payload sections are 2,048 bytes each and sit after `.rodata`. Their names
and the `unknvma` markers indicate a DVP/SN Systems overlay linker whose final VMA is
resolved at load time. Upstream `ps2-native-recomp` handles dynamically loaded code
generically: its exploratory runs capture unseen code windows into `games/roadrage/overlays/`
and the next build translates them ahead of time. No manual DVP decoder is needed for the
first working build.

## 4. Engine and middleware

- **Pure3D** (Radical Entertainment's engine). The ELF contains `PURE3D ASSERTION FAILED`,
  `Scenegraph`, `TransformAnimation`, `LoadManager`, `GridManager`, `SkidMark`,
  `DataLoadManager` and vehicle/character database code (`DBLoader::LoadVehicleDB`).
- **RADSound** middleware: `radsound.irx`, `radSound: IopVoiceServer version [0x104]`,
  `IRadFileCompletionCallback`, `IRadMoviePlayerCallback`.
- Sony SDK: `sio2man`, `mtapman`, `padman`, `libsd`, `sdrdrv`, `mcman`, `mcserv`, `usbd`,
  `lgdev`, `IOPRP214.IMG`.
- PSS FMV player (`movies\pal\*.pss`).
- RTTI and C++ exceptions mean generated code must preserve EE register state and stack
  behaviour exactly; the upstream recompiler emits literal per-instruction C++.

## 5. Runtime observations from the native runner (baseline build)

The following were observed in `analysis/run_baseline.log` at 600 frames:

- `[disc] 70 files, 1214640 sectors`; boot ELF read from the disc.
- IOP reboot with `rom0:UDNL cdrom0:\IOPRP214.IMG;1`, async FILEIO, LOADFILE.
- All ten IRX modules loaded at the addresses logged in the report.
- RADSound voice/load servers started; `SDR driver version 2.0.0`.
- Memory card: `DelDrv mc` (no driver yet), then `AddDrv mc`.
- GS `SetGsCrt interlace 1 mode 0x3 field 0`; GIF/DMA tag traffic observed.
- EE threads 1–5 running/ready/asleep with stacks in `0x0020..0x0031` — i.e. real game
  threads, not a crash loop.
- Rendering backend: NVIDIA GeForce RTX 2080 SUPER, Direct3D 12, DXC shaders.
- Two benign file-driver probes return -2: `hosthost:always.rcf`, `snfisnfile:always.rcf`.
  The game continues; `always.rcf` is subsequently opened normally from the disc.
- No `[ee] unsupported`, no syscall TODOs, no faults.

## 6. PAL-specific considerations

- `VMODE = PAL` in `SYSTEM.CNF`; the runtime reproduces the PAL GS display registers.
- Disc files are under `MOVIES/PAL/` — the English PAL build has only PAL FMVs.
- PCSX2's compatibility page marks this title as **software rendering only** and lists a
  widescreen patch. That suggests the GS is driven in an unusual way; visual verification
  at the menu/gameplay stage is required before claiming correctness.
- Original PAL timing (~50 Hz) must remain the baseline; no frame-rate patches are applied.

## 7. Open questions

1. Do the eight DVP overlays contain level-specific code that must be captured before
   gameplay, or only VU data? (Exploratory build recorded 42 VU1 programs and 0 new EE
   windows; manual DVP decoding is still unnecessary.)
2. Does RADSound need a host-side implementation for music/voice, or is running the disc's
   `RADSOUND.IRX` sufficient? (IRX is running; audible output not yet verified.)
3. What do the mostly-black captured frames represent at frame 600? (Answered by later
   captures: pre-title FMV/fade. The title screen appears around frame 2000; see
   `PROGRESS.md`.)
