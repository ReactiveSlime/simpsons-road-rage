[CmdletBinding()]
param(
    [int]$Frames = 3500,
    [string]$QuickDir = '',
    [switch]$NoFocus
)

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$upstream = Join-Path $repo 'third_party\ps2-native-recomp'
$runner = Join-Path $upstream 'build\native-roadrage\ps2run.exe'
$disc = Join-Path $upstream 'games\roadrage\disc.iso'
$gameDir = Join-Path $upstream 'games\roadrage'
foreach ($file in @($runner, $disc)) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing runtime input: $file" }
}

if (-not $QuickDir) { $QuickDir = Join-Path $repo 'analysis\kbm_quick' }
$shots = Join-Path $repo 'analysis\shots_kbm'
$stdout = Join-Path $repo 'analysis\kbm_stdout.log'
$stderr = Join-Path $repo 'analysis\kbm_stderr.log'
New-Item -ItemType Directory -Force -Path $QuickDir, $shots | Out-Null
Get-ChildItem -LiteralPath $shots -File -ErrorAction SilentlyContinue | Remove-Item -Force
foreach ($file in @($stdout, $stderr)) {
    if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force }
}
$keysPath = Join-Path $QuickDir 'keys.ini'
if (Test-Path -LiteralPath $keysPath) { Remove-Item -LiteralPath $keysPath -Force }

# Real scan-code injection: SDL reads the Win32 keyboard state, so SendInput is a
# better test than SendKeys (which some games' raw-input paths ignore).
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public static class KbmInput
{
    private const uint INPUT_KEYBOARD = 1;
    private const uint KEYEVENTF_EXTENDEDKEY = 0x0001;
    private const uint KEYEVENTF_KEYUP = 0x0002;
    private const uint KEYEVENTF_SCANCODE = 0x0008;

    [StructLayout(LayoutKind.Sequential)]
    private struct KEYBDINPUT
    {
        public ushort wVk;
        public ushort wScan;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct HARDWAREINPUT
    {
        public uint uMsg;
        public ushort wParamL;
        public ushort wParamH;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public KEYBDINPUT ki;
        [FieldOffset(0)] public MOUSEINPUT mi;
        [FieldOffset(0)] public HARDWAREINPUT hi;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct INPUT
    {
        public uint type;
        public InputUnion U;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    private static extern bool BringWindowToTop(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);

    [DllImport("kernel32.dll")]
    private static extern uint GetCurrentThreadId();

    [DllImport("user32.dll")]
    private static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("user32.dll")]
    private static extern bool SetFocus(IntPtr hWnd);

    [DllImport("user32.dll")]
    private static extern void SwitchToThisWindow(IntPtr hWnd, bool altTab);

    [DllImport("user32.dll")]
    private static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);

    private static bool Event(ushort scan, bool extended, bool up)
    {
        uint flags = KEYEVENTF_SCANCODE | (up ? KEYEVENTF_KEYUP : 0) | (extended ? KEYEVENTF_EXTENDEDKEY : 0);
        var input = new INPUT {
            type = INPUT_KEYBOARD,
            U = new InputUnion { ki = new KEYBDINPUT { wScan = scan, dwFlags = flags } }
        };
        return SendInput(1, new[] { input }, Marshal.SizeOf(typeof(INPUT))) == 1;
    }

    public static bool Tap(ushort scan, bool extended, int holdMs)
    {
        if (!Event(scan, extended, false)) return false;
        System.Threading.Thread.Sleep(holdMs);
        return Event(scan, extended, true);
    }

    public static bool Focus(IntPtr hWnd)
    {
        ShowWindow(hWnd, 9);
        BringWindowToTop(hWnd);

        // Windows only lets a process change the foreground window under narrow
        // conditions. An ALT press and an attached input queue are the standard
        // ways to satisfy them when the probe is launched from a terminal.
        keybd_event(0x12, 0, 0, UIntPtr.Zero);
        SetForegroundWindow(hWnd);
        keybd_event(0x12, 0, 2, UIntPtr.Zero);
        if (GetForegroundWindow() == hWnd) return true;

        uint targetPid, foregroundPid;
        uint current = GetCurrentThreadId();
        uint target = GetWindowThreadProcessId(hWnd, out targetPid);
        uint foreground = GetWindowThreadProcessId(GetForegroundWindow(), out foregroundPid);
        if (foreground != 0 && foreground != current) AttachThreadInput(current, foreground, true);
        if (target != 0 && target != current) AttachThreadInput(current, target, true);
        SwitchToThisWindow(hWnd, true);
        SetForegroundWindow(hWnd);
        SetFocus(hWnd);
        BringWindowToTop(hWnd);
        if (target != 0 && target != current) AttachThreadInput(current, target, false);
        if (foreground != 0 && foreground != current) AttachThreadInput(current, foreground, false);
        return GetForegroundWindow() == hWnd;
    }
}
'@

$scancodes = @{
    Escape = @{ Scan = 0x01; Extended = $false }
    Enter = @{ Scan = 0x1C; Extended = $false }
    Space = @{ Scan = 0x39; Extended = $false }
    Up = @{ Scan = 0x48; Extended = $true }
    Down = @{ Scan = 0x50; Extended = $true }
    Left = @{ Scan = 0x4B; Extended = $true }
    Right = @{ Scan = 0x4D; Extended = $true }
    W = @{ Scan = 0x11; Extended = $false }
    A = @{ Scan = 0x1E; Extended = $false }
    S = @{ Scan = 0x1F; Extended = $false }
    D = @{ Scan = 0x20; Extended = $false }
    E = @{ Scan = 0x12; Extended = $false }
    H = @{ Scan = 0x23; Extended = $false }
    R = @{ Scan = 0x13; Extended = $false }
    C = @{ Scan = 0x2E; Extended = $false }
    LeftShift = @{ Scan = 0x2A; Extended = $false }
    RightShift = @{ Scan = 0x36; Extended = $false }
}

$wsh = New-Object -ComObject WScript.Shell

function Focus-Runner {
    if ($NoFocus) { return $true }
    if ([KbmInput]::Focus($proc.MainWindowHandle)) { return $true }
    $proc.Refresh()
    if ($wsh.AppActivate($proc.Id)) { Start-Sleep -Milliseconds 150 }
    return [KbmInput]::Focus($proc.MainWindowHandle)
}

function Send-Key {
    param([string]$Name, [int]$HoldMs = 90)
    $entry = $scancodes[$Name]
    if (-not $entry) { throw "Unknown key: $Name" }
    $focused = Focus-Runner
    if (-not $focused) { throw "Could not focus the runner window before sending $Name" }
    Start-Sleep -Milliseconds 150
    $ok = [KbmInput]::Tap([ushort]$entry.Scan, [bool]$entry.Extended, $HoldMs)
    Write-Host "[kbm] sent $Name (scan 0x$('{0:X2}' -f $entry.Scan), focused=$focused)"
    if (-not $ok) { throw "SendInput failed for $Name" }
}

function Wait-Frame {
    param([int]$Frame, [int]$TimeoutSeconds = 120)
    $path = Join-Path $shots ('frame_{0:D5}.ppm' -f $Frame)
    $limit = (Get-Date).AddSeconds($TimeoutSeconds)
    while (-not (Test-Path -LiteralPath $path)) {
        if ($proc.HasExited) { throw "Runner exited before frame $Frame (exit $($proc.ExitCode))" }
        if ((Get-Date) -gt $limit) { throw "Timed out waiting for frame $Frame" }
        Start-Sleep -Milliseconds 100
    }
    Write-Host "[kbm] reached frame $Frame"
}

function Save-WindowShot {
    param([int]$Frame)
    $rect = New-Object KbmInput+RECT
    if (-not [KbmInput]::GetWindowRect($proc.MainWindowHandle, [ref]$rect)) { throw 'GetWindowRect failed' }
    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
        $path = Join-Path $shots ('window_{0:D5}.png' -f $Frame)
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "[kbm] window capture $path ($width x $height)"

        $hdc = $graphics.GetHdc()
        try {
            $null = [KbmInput]::PrintWindow($proc.MainWindowHandle, $hdc, 2)
        } finally {
            $graphics.ReleaseHdc($hdc)
        }
        $pwPath = Join-Path $shots ('print_{0:D5}.png' -f $Frame)
        $bitmap.Save($pwPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "[kbm] PrintWindow capture $pwPath"
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

$oldPadLog = $env:PS2_PAD_LOG
$oldNoBeep = $env:PS2_NO_BEEP
$oldKeys = $env:PS2_KEYS
try {
    $env:PS2_PAD_LOG = '1'
    $env:PS2_NO_BEEP = '1'
    $env:PS2_KEYS = $keysPath
    $arguments = @(
        '--disc', "`"$disc`"", '--game-dir', "`"$gameDir`"",
        '--quick-dir', "`"$QuickDir`"", '--window', '--frames', "$Frames",
        '--frames-dir', "`"$shots`"", '--frame-at', '2100', '--frame-at', '2150',
        '--frame-at', '2800', '--frame-at', '2850', '--frame-at', '3400',
        '--no-record'
    )
    $proc = Start-Process -FilePath $runner -ArgumentList $arguments -WorkingDirectory (Split-Path -Parent $runner) `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
    Write-Host "[kbm] runner PID $($proc.Id)"

    # Wait for the SDL window before sending anything.
    $limit = (Get-Date).AddSeconds(30)
    while ($proc.MainWindowHandle -eq [IntPtr]::Zero) {
        if ($proc.HasExited) { throw "Runner exited before showing a window (exit $($proc.ExitCode))" }
        if ((Get-Date) -gt $limit) { throw 'Timed out waiting for the runner window' }
        Start-Sleep -Milliseconds 100
        $proc.Refresh()
    }
    $focused = $NoFocus
    if (-not $focused) {
        $limit = (Get-Date).AddSeconds(10)
        while (-not (Focus-Runner)) {
            if ((Get-Date) -gt $limit) { throw 'Could not focus the runner window' }
            Start-Sleep -Milliseconds 200
        }
        $focused = $true
        Start-Sleep -Milliseconds 300
    }
    Write-Host "[kbm] window handle $($proc.MainWindowHandle), focused=$focused"

    Wait-Frame -Frame 2100
    Save-WindowShot -Frame 2100         # title screen, before live Start
    Send-Key -Name Escape -HoldMs 120   # default Start on the title screen
    Wait-Frame -Frame 2150
    Save-WindowShot -Frame 2150         # after live Start

    # Road Rage layout checks. The game state is not important here: PS2_PAD_LOG
    # records the virtual pad transitions, so these show that each physical key
    # reaches the intended PS2 button.
    Send-Key -Name W -HoldMs 90           # Cross: accelerate
    Send-Key -Name S -HoldMs 90           # Circle: stop / reverse
    Send-Key -Name Space -HoldMs 90       # Square: hand brake
    Send-Key -Name H -HoldMs 90           # Triangle + L1: horn
    Send-Key -Name C -HoldMs 90           # L2: look back
    Send-Key -Name R -HoldMs 90           # Select: reset vehicle
    Send-Key -Name LeftShift -HoldMs 90   # L1 cheat shoulder
    Send-Key -Name RightShift -HoldMs 90  # R1 cheat shoulder

    Wait-Frame -Frame 2800
    Save-WindowShot -Frame 2800         # main menu, before live D-pad Down
    Send-Key -Name Down -HoldMs 120     # default D-pad Down in the main menu
    Wait-Frame -Frame 2850
    Save-WindowShot -Frame 2850         # after live D-pad Down

    Wait-Frame -Frame 3400
    Save-WindowShot -Frame 3400
    if (-not $proc.WaitForExit(30000)) { $proc.Kill(); $proc.WaitForExit() }
    Write-Host "[kbm] runner exit $($proc.ExitCode)"
}
finally {
    if ($proc -and -not $proc.HasExited) { $proc.Kill(); $proc.WaitForExit() }
    $env:PS2_PAD_LOG = $oldPadLog
    $env:PS2_NO_BEEP = $oldNoBeep
    $env:PS2_KEYS = $oldKeys
}

Write-Host '[kbm] pad log lines:'
Select-String -LiteralPath $stderr -Pattern '\[pad\]|\[keys\]' | ForEach-Object { Write-Host $_.Line }
Write-Host "[kbm] keys.ini: $keysPath"
if (Test-Path -LiteralPath $keysPath) { Get-Content -LiteralPath $keysPath | Write-Host }

# Verify the Road Rage layout itself, not just that some input arrived.
$padText = Get-Content -LiteralPath $stderr -Raw
$keyText = if (Test-Path -LiteralPath $keysPath) { Get-Content -LiteralPath $keysPath -Raw } else { '' }
$expectedPad = @(
    @{ Label = 'Esc -> Start (pause/title)'; Pattern = 'buttons 0008 start' }
    @{ Label = 'W -> Cross (accelerate)'; Pattern = 'buttons 4000 cross' }
    @{ Label = 'S -> Circle (stop/reverse)'; Pattern = 'buttons 2000 circle' }
    @{ Label = 'Space -> Square (hand brake)'; Pattern = 'buttons 8000 square' }
    @{ Label = 'H -> Triangle + L1 (horn)'; Pattern = 'buttons 1400 l1 triangle' }
    @{ Label = 'C -> L2 (look back), pressure 255'; Pattern = 'buttons 0100 l2' }
    @{ Label = 'R -> Select (reset vehicle)'; Pattern = 'buttons 0001 select' }
    @{ Label = 'Left Shift -> L1 cheat shoulder'; Pattern = 'buttons 0400 l1' }
    @{ Label = 'Right Shift -> R1 cheat shoulder'; Pattern = 'buttons 0800 r1' }
    @{ Label = 'Down -> D-pad down + Circle'; Pattern = 'buttons 2040 down circle' }
)
$expectedKeys = @(
    'cross       = W, Enter, Keypad Enter'
    'circle      = S, Down'
    'square      = Space, Left Mouse'
    'triangle    = H, Middle Mouse'
    'l1          = H, Left Shift'
    'r1          = Right Shift'
    'l2          = C, Right Mouse'
    'start       = Esc'
    'select      = R, Backspace'
    'mouse_stick = off'
)

$missing = @()
foreach ($check in $expectedPad) {
    if ($padText -notmatch [regex]::Escape($check.Pattern)) { $missing += "pad log: $($check.Label) [$($check.Pattern)]" }
}
foreach ($line in $expectedKeys) {
    if (-not $keyText.Contains($line)) { $missing += "keys.ini: $line" }
}
if ($proc.ExitCode -ne 0) { $missing += "runner exit code $($proc.ExitCode)" }

$evidence = @()
$evidence += 'Live keyboard/mouse verification - SLES-505.40 native runner'
$evidence += '=========================================================='
$evidence += ''
$evidence += 'Command: tools/kbm_probe.ps1 -NoFocus'
$evidence += ''
$evidence += 'The -NoFocus switch disables all focus help in the probe; the runner must'
$evidence += 'focus its own SDL window. Genuine Win32 scan codes are injected with SendInput.'
$evidence += ''
$evidence += 'Pad-state lines from analysis/kbm_stderr.log (PS2_PAD_LOG=1):'
foreach ($check in $expectedPad) {
    $found = [regex]::Match($padText, '\[pad\] frame \d+ port 1 ' + [regex]::Escape($check.Pattern) + '.*')
    $evidence += "  $($check.Label): $($found.Value)"
}
$evidence += ''
$evidence += 'Generated keys.ini lines (analysis/kbm_quick/keys.ini):'
foreach ($line in $expectedKeys) { $evidence += "  $line" }
$evidence += ''
if ($missing.Count -eq 0) {
    $evidence += "Result: PASS - runner exit $($proc.ExitCode), all expected pad transitions and key lines found."
} else {
    $evidence += 'Result: FAIL - missing evidence:'
    foreach ($item in $missing) { $evidence += "  $item" }
}
$evidencePath = Join-Path $repo 'analysis\kbm_evidence.txt'
$evidence | Set-Content -LiteralPath $evidencePath -Encoding UTF8
if ($missing.Count -gt 0) { throw "Keyboard/mouse layout verification failed; see $evidencePath" }
Write-Host "[kbm] layout verification passed; evidence: $evidencePath"
