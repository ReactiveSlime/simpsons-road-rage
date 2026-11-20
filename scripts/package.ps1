[CmdletBinding()]
param([switch]$SkipIsoCopy)

. (Join-Path $PSScriptRoot 'common.ps1')

$repo = Get-RepoRoot
$upstream = Join-Path $repo 'third_party\ps2-native-recomp'
$build = Join-Path $upstream 'build\native-roadrage'
$game = Join-Path $upstream 'games\roadrage'
$dist = Join-Path $repo 'dist\roadrage'
$gameOut = Join-Path $dist 'game'

$required = @(
    (Join-Path $build 'ps2run.exe'),
    (Join-Path $build 'SDL2.dll'),
    (Join-Path $build 'dxcompiler.dll'),
    (Join-Path $build 'dxil.dll'),
    (Join-Path $game 'disc.iso')
)
foreach ($file in $required) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing build output: $file" }
}

if (Test-Path -LiteralPath $dist) { Remove-Item -LiteralPath $dist -Recurse -Force }
New-Item -ItemType Directory -Force -Path $gameOut | Out-Null

foreach ($name in @('ps2run.exe', 'SDL2.dll', 'dxcompiler.dll', 'dxil.dll')) {
    Copy-Item -LiteralPath (Join-Path $build $name) -Destination (Join-Path $dist $name)
}
foreach ($name in @('entries.txt', 'vu0', 'vu1', 'overlays', 'disc')) {
    $source = Join-Path $game $name
    if (Test-Path -LiteralPath $source) { Copy-Item -LiteralPath $source -Destination (Join-Path $gameOut $name) -Recurse }
}
if (-not $SkipIsoCopy) {
    Write-Host 'Copying the 2.5 GB disc image into the package (this is your own ISO)...'
    Copy-Item -LiteralPath (Join-Path $game 'disc.iso') -Destination (Join-Path $gameOut 'disc.iso')
}

@'
@echo off
cd /d "%~dp0"
ps2run.exe --disc game\disc.iso --game-dir game --window %*
'@ | Set-Content -LiteralPath (Join-Path $dist 'PLAY.cmd') -Encoding ASCII

@'
The Simpsons: Road Rage (SLES-505.40, PAL) - native Windows build

PLAY.cmd starts the game. It uses the disc image in game\ under the user's own
copyrighted copy of the game. No PCSX2 installation, BIOS image or emulator
process is used.

This repository does not redistribute the ISO, boot ELF, IRX modules, extracted
assets or generated C++ translations. The package script copies them only from
the local build made from the user's own disc.

Optional arguments are passed to ps2run, for example:
  PLAY.cmd --frames 6000 --press 2100:start --no-record
'@ | Set-Content -LiteralPath (Join-Path $dist 'README.txt') -Encoding UTF8

$hashLines = foreach ($name in @('ps2run.exe', 'SDL2.dll', 'dxcompiler.dll', 'dxil.dll')) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $dist $name) -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $name"
}
$hashLines | Set-Content -LiteralPath (Join-Path $dist 'SHA256SUMS.txt') -Encoding ASCII

Write-Host "Package ready: $dist"
Write-Host "Start with: $(Join-Path $dist 'PLAY.cmd')"
