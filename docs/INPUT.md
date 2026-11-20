# Keyboard and mouse controls

Live keyboard and mouse input is supported by the native runner. No controller
or PCSX2 is required. The defaults are now a Road Rage driving layout rather
than the upstream runner's generic action-game layout.

## Original PS2 controls

The PAL manual's "Complete Controls" page was OCR'd locally from the scanned
manual; the button names were cross-checked against the PSX Data Center control
list and the 2002 Road Rage FAQ. The controls are:

| Action | Original PS2 control |
|---|---|
| Steering | D-pad left/right **or** left analog stick left/right |
| Accelerate | X (Cross) **or** right analog stick up |
| Stop, then reverse | Circle **or** right analog stick down |
| Hand brake / burnout | Square; hold it, steer, then accelerate to spin |
| Horn | Triangle **or** L1 |
| Look back | L2 |
| Reset vehicle | Select |
| Pause / pause menu | Start |
| Menus | D-pad highlights/cycles, X confirms, Triangle returns |

R1/R2 and the pressed-in sticks (L3/R3) are not needed for normal driving;
shoulder buttons appear in cheat codes. The manual scan's glyph OCR was
ambiguous on one alternate hand-brake line, but the FAQ and PSX Data Center both
identify Square as the hand brake, so Square is the action used here.

Sources:

- `https://www.gamesdatabase.org/Media/SYSTEM/Sony_Playstation_2/manual/Formated/Simpsons_-_Road_Rage,_The_-_2001_-_Radical_Entertainment.pdf`
- `https://psxdatacenter.com/psx2/games2/SLUS-20305.html`
- `https://www.neoseeker.com/simp-roadrage/faqs/46390-simpsons-road-rage.html`

The NTSC-U control list and the PAL manual agree on the action names; only the
verified PAL disc (`SLES-505.40`) is built and shipped by this project.

## Default bindings

| Road Rage action | PS2 button | Keyboard / mouse |
|---|---|---|
| Accelerate / menu confirm | Cross | `W`, `Enter`, keypad `Enter` |
| Stop / reverse | Circle | `S`, `Down` |
| Steer left / right | Left stick | `A` / `D` |
| Steer left / right | D-pad | `Left` / `Right` |
| Hand brake | Square | `Space`, left mouse |
| Horn / menu back | Triangle | `H`, middle mouse |
| Horn / cheat shoulder | L1 | `H`, left `Shift` |
| Cheat shoulder | R1 | right `Shift` |
| Look back | L2 | `C`, right mouse |
| Reset vehicle | Select | `R`, `Backspace` |
| Pause / title Start | Start | `Esc` |
| Menu up / down | D-pad | `Up` / `Down` |

`H` deliberately presses both Triangle and L1 because both sound the horn on
the PS2; left `Shift` remains as the separate L1 cheat shoulder. `Down` is both
menu navigation and stop/reverse. R2, L3, R3, the right stick and the runner's
Roll/Rage modifiers are unbound in this layout.

Runner keys are unchanged:

- `F1` opens the quick menu, where **Keys** shows the Road Rage key card and
  **Change keys** can rebind buttons.
- `F2` cycles the picture look; `F5` quick save; `F8` quick load; `F9` problem
  report; `F11` toggles fullscreen.
- `Left Ctrl`, mouse button X1 and `V` are generic runner modifiers; they are
  unbound in the Road Rage defaults.

The mouse can push a stick instead of only clicking. Edit `keys.ini` and set
`mouse_stick = left` or `mouse_stick = right`; `mouse_speed`, `mouse_invert` and
`mouse_deadzone` control that mode. It is `off` by default, so the mouse only
clicks the bindings above.

## Start and focus

```powershell
cd third_party\ps2-native-recomp
.\build\native-roadrage\ps2run.exe --disc games\roadrage\disc.iso --game-dir games\roadrage --window
```

The window takes keyboard focus when it opens. A Windows-specific patch in
`patches/0001-windows-kbm-focus.patch` strengthens the upstream focus call so
this also works when the game is launched from a terminal. If another window is
clicked afterwards, click the game window again before using the keyboard.

## `keys.ini`

The file is created next to the memory-card/quick-save data. Its exact path is
printed at startup as `[keys] ... wrote ... keys.ini with the default keys`. It
can also be forced with `--quick-dir <folder>` or the `PS2_KEYS` environment
variable.

Each line is `action = key, key, key`; `none` disables an action. The file is
reread when the game window regains focus, so changes can be made while the game
is running. **Delete an existing `keys.ini` to get the Road Rage defaults**;
old files from a previous build override the new defaults until removed.

## Verification

`tools/kbm_probe.ps1` is the reproducible live-input test. It launches a real
windowed run with `PS2_PAD_LOG=1`, injects genuine Win32 scan codes, checks the
resulting pad-state transitions and generated `keys.ini` lines, then writes
`analysis/kbm_evidence.txt`:

```powershell
./tools/kbm_probe.ps1
./tools/kbm_probe.ps1 -NoFocus   # also verifies the runner's own focus patch
```

The latest run used `-NoFocus`. It confirmed `Esc` → `start`, `W` → `cross`,
`S` → `circle`, `Space` → `square`, `H` → `l1 + triangle`, `C` → `l2` with
pressure 255, `R` → `select`, left/right `Shift` → `l1`/`r1`, and `Down` →
`down + circle`. The generated file had zero parse problems and
`mouse_stick = off`. The raw log is `analysis/kbm_stderr.log`.

Windowed D3D12 output cannot be read back by GDI `CopyFromScreen` or
`PrintWindow`, so visual state confirmation uses the matching headless run in
`analysis/shots_kbm_headless/`; the live pad log is the evidence that keyboard
input reaches the same virtual controller.
