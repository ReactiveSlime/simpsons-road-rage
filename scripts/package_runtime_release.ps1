[CmdletBinding()]
param(
    [string]$Version = 'v0.1.0',
    [string]$OutZip
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repo = Get-RepoRoot
$upstream = Join-Path $repo 'third_party\ps2-native-recomp'
$build = Join-Path $upstream 'build\native-roadrage'
$dist = Join-Path $repo 'dist'
$stage = Join-Path $dist 'roadrage-runtime'
if (-not $OutZip) { $OutZip = Join-Path $dist "roadrage-runtime-$Version.zip" }

$binaries = @('ps2run.exe', 'SDL2.dll', 'dxcompiler.dll', 'dxil.dll')
foreach ($name in $binaries) {
    if (-not (Test-Path -LiteralPath (Join-Path $build $name))) {
        throw "Missing build output: $name. Run scripts/build.ps1 first."
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $upstream 'LICENSE'))) {
    throw 'Missing upstream LICENSE in the pinned third_party checkout.'
}

New-Item -ItemType Directory -Force -Path $dist | Out-Null
if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

foreach ($name in $binaries) {
    Copy-Item -LiteralPath (Join-Path $build $name) -Destination (Join-Path $stage $name)
}
Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination (Join-Path $stage 'LICENSE-project.txt')
Copy-Item -LiteralPath (Join-Path $upstream 'LICENSE') -Destination (Join-Path $stage 'LICENSE-upstream.txt')

@'
@echo off
cd /d "%~dp0"
if not exist "game\disc.iso" (
  echo Place your own SLES-505.40 disc image at game\disc.iso
  echo and generate the game caches with the source build first. See README.txt.
  exit /b 1
)
ps2run.exe --disc game\disc.iso --game-dir game --window %*
'@ | Set-Content -LiteralPath (Join-Path $stage 'PLAY.cmd') -Encoding ASCII

@"
Road Rage Native Recomp - runtime-only package

Version: $Version
Target: Windows x64, The Simpsons: Road Rage SLES-505.40 (English PAL Europe).

This ZIP contains only the standalone runner binaries and licence texts.
It deliberately contains NO ISO, game files, extracted assets, generated C++,
recompiler caches, captured imagery, BIOS image or PCSX2 component.

To play, you must supply your own legally owned disc and build its data once:

  1. Clone https://github.com/ReactiveSlime/simpsons-road-rage
  2. Follow docs/BUILDING.md for prerequisites, then run:
       python -m pip install -r requirements.txt
       ./scripts/setup.ps1
       ./scripts/build.ps1 -Iso "path\to\your\SLES-505.40.iso"
  3. Copy the generated third_party/ps2-native-recomp/games/roadrage/* contents
     (entries.txt, vu0, vu1, overlays, disc/, disc.iso) into this folder's game/.
  4. Run PLAY.cmd.

Do not redistribute the ISO or generated game data. GitHub's source archive for
this release contains only the committed source text, patches and evidence.

Optional runner arguments are passed through, for example:
  PLAY.cmd --frames 6000 --press 2100:start --no-record
"@ | Set-Content -LiteralPath (Join-Path $stage 'README.txt') -Encoding UTF8

$hashLines = foreach ($name in $binaries) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $stage $name) -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $name"
}
$hashLines | Set-Content -LiteralPath (Join-Path $stage 'SHA256SUMS.txt') -Encoding ASCII

$allowed = $binaries + @('PLAY.cmd', 'README.txt', 'SHA256SUMS.txt', 'LICENSE-project.txt', 'LICENSE-upstream.txt')
$unexpected = Get-ChildItem -LiteralPath $stage -Recurse -File | Where-Object { $_.Name -notin $allowed }
if ($unexpected) {
    throw "Unexpected file would be packaged: $($unexpected.FullName -join ', ')"
}

if (Test-Path -LiteralPath $OutZip) { Remove-Item -LiteralPath $OutZip -Force }
Get-ChildItem -LiteralPath $stage | Compress-Archive -DestinationPath $OutZip -CompressionLevel Optimal
Write-Host "Runtime-only ZIP ready: $OutZip"
