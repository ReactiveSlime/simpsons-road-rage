# Keyboard and mouse controls

Live keyboard and mouse input is supported by the native runner. No controller
or PCSX2 is required.

## Start and focus

```powershell
cd third_party\ps2-native-recomp
.\build\native-roadrage\ps2run.exe --disc games\roadrage\disc.iso --game-dir games\roadrage --window
```

The window takes keyboard focus when it opens. A Windows-specific patch in
`patches/0001-windows-kbm-focus.patch` strengthens the upstream focus call so
this also works when the game is launched from a terminal. If another window is
clicked afterwards, click the game window again before using the keyboard.

## Default bindings

| PS2 button | Keyboard / mouse |
|---|---|
| D-pad | Arrow keys |
| Left stick | `W` `A` `S` `D` |
| Right stick | `I` `J` `K` `L` |
| Cross | `Space`, `Enter`, keypad `Enter` |
| Circle | `E`, middle mouse |
| Square | left mouse |
| Triangle | right mouse |
| L1 / R1 | left `Shift` / `F` |
| L2 / R2 | `Q` / `R` |
| L3 / R3 | `X` / `C` |
| Start | `Esc` |
| Select | `Tab`, `Backspace` |

Additional runner keys:

- `F1` opens the quick menu, where **Keys** shows the key card and **Change keys**
  can rebind buttons.
- `F2` cycles the picture look; `F5` quick save; `F8` quick load; `F9` problem
  report; `F11` toggles fullscreen.
- `Left Ctrl` (or mouse button X1) is the God of War-style roll modifier and `V`
  presses L3+R3 together. Neither is needed for Road Rage.

The mouse can also push a stick instead of only clicking. Edit `keys.ini` and set
`mouse_stick = left` or `mouse_stick = right`; the related `mouse_speed`,
`mouse_invert` and `mouse_deadzone` lines control it. It is `off` by default.

## `keys.ini`

The file is created next to the memory-card/quick-save data. Its exact path is
printed at startup as `[keys] ... wrote ... keys.ini with the default keys`. It
can also be forced with `--quick-dir <folder>` or the `PS2_KEYS` environment
variable.

Each line is `action = key, key, key`; `none` disables an action. The file is
reread when the game window regains focus, so changes can be made while the game
is running. Delete it to return to the defaults.

## Verification

`tools/kbm_probe.ps1` is the reproducible live-input test. It launches a real
windowed run with `PS2_PAD_LOG=1`, injects genuine Win32 scan codes and records
the resulting pad-state transitions:

```powershell
./tools/kbm_probe.ps1
./tools/kbm_probe.ps1 -NoFocus   # also verifies the runner's own focus patch
```

The latest evidence is in `analysis/kbm_evidence.txt`; the full runner log is
`analysis/kbm_stderr.log`. It confirms that `Esc` reaches the virtual pad as
`start` and `Down` reaches it as D-pad `down`, with clean key releases. The
windowed D3D12 swapchain cannot be read back by GDI `CopyFromScreen` or
`PrintWindow`, so visual state confirmation uses the matching headless run in
`analysis/shots_kbm_headless/` instead.
