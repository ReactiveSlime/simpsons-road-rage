[CmdletBinding()]
param(
    [string]$Iso,
    [switch]$NoExplore,
    [switch]$Clean,
    [switch]$SkipValidation,
    [int]$Frames = 6000,
    [int]$Rounds = 6,
    [string[]]$Press
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repo = Get-RepoRoot
$upstream = Join-Path $repo 'third_party\ps2-native-recomp'
$buildDir = Join-Path $repo 'build'
if (-not (Test-Path -LiteralPath $buildDir)) { New-Item -ItemType Directory -Force -Path $buildDir | Out-Null }
if (-not $Iso) { $Iso = Join-Path $repo 'Simpsons Road Rage PS2 PAL.iso' }
$Iso = (Resolve-Path -LiteralPath $Iso).Path

if (-not $SkipValidation) {
    Write-Host "Validating $Iso"
    $code = Invoke-LoggedNative -FilePath (Join-Path $buildDir 'validate_iso.log') -Body {
        python (Join-Path $repo 'tools\validate_iso.py') --iso $Iso --json (Join-Path $repo 'analysis\iso_validation.json')
    }
    Assert-ZeroExit $code 'ISO validation failed; only SLES-505.40 (English PAL) is supported'
} else {
    Write-Warning 'ISO validation skipped by request.'
}

if (-not (Test-Path -LiteralPath (Join-Path $upstream 'build\tools\eerecomp.exe')) -and
    -not (Test-Path -LiteralPath (Join-Path $upstream 'build\tools\eerecomp'))) {
    throw 'Upstream tools are missing. Run scripts/setup.ps1 first.'
}
& (Join-Path $PSScriptRoot 'apply_patches.ps1')

if ($Clean) {
    foreach ($relative in @('generated\roadrage', 'games\roadrage', 'build\native-roadrage')) {
        $target = Join-Path $upstream $relative
        if (Test-Path -LiteralPath $target) {
            Write-Host "Clean: $target"
            Remove-Item -LiteralPath $target -Recurse -Force
        }
    }
}

$bash = Find-GitBash
$clang = Find-LlvmMingwClang
$env:PATH = "$((Split-Path -Parent $clang));$env:PATH"
$env:CXX = Convert-To-MsysPath -WindowsPath $clang -Bash $bash
$isoMsys = Convert-To-MsysPath -WindowsPath $Iso -Bash $bash

if (-not $Press -or $Press.Count -eq 0) {
    # Start is pressed after the PRESS START prompt appears (~frame 1900).
    $Press = @(
        '1800:start:8', '2100:cross:8', '2400:start:8', '2700:cross:8',
        '3100:cross:8', '3400:cross:8', '3700:cross:8', '4000:start:8',
        '4300:cross:8', '4600:cross:8', '4900:start:8', '5200:cross:8',
        '5500:cross:8'
    )
}

$parts = [System.Collections.Generic.List[string]]::new()
$parts.Add("scripts/port.sh roadrage '$isoMsys' --native-only")
if ($NoExplore) {
    $parts.Add('--no-explore')
} else {
    $parts.Add("--frames $Frames")
    $parts.Add("--rounds $Rounds")
    foreach ($p in $Press) { $parts.Add("--press '$p'") }
}
$command = $parts -join ' '
$logName = if ($NoExplore) { 'port_baseline.log' } else { 'port_explore.log' }

Write-Host "Building native executable (explore=$(-not $NoExplore))..."
$code = Invoke-LoggedNative -FilePath (Join-Path $buildDir $logName) -Body {
    Push-Location $upstream
    try { & $bash -lc $command }
    finally { Pop-Location }
}
Assert-ZeroExit $code "port.sh failed; see build/$logName"

$exe = Join-Path $upstream 'build\native-roadrage\ps2run.exe'
if (-not (Test-Path -LiteralPath $exe)) { throw "Build finished without $exe" }
Write-Host ''
Write-Host "Native executable: $exe"
Write-Host 'Play from the upstream root with:'
Write-Host '  build/native-roadrage/ps2run.exe --disc games/roadrage/disc.iso --game-dir games/roadrage --window'
Write-Host 'Next: scripts/package.ps1'
