[CmdletBinding()]
param(
    [string]$Commit = '74912bd8e57c327a02242cde4df36f12e986a2c0',
    [string]$Url = 'https://github.com/exoteric33/ps2-native-recomp.git',
    [switch]$SkipUpstreamSetup
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repo = Get-RepoRoot
$upstream = Join-Path $repo 'third_party\ps2-native-recomp'
$buildDir = Join-Path $repo 'build'
if (-not (Test-Path -LiteralPath $buildDir)) { New-Item -ItemType Directory -Force -Path $buildDir | Out-Null }

Write-Host "Repository : $repo"
Write-Host "Upstream   : $upstream @ $Commit"

if (-not (Test-Path -LiteralPath (Join-Path $upstream '.git'))) {
    if (Test-Path -LiteralPath $upstream) { throw "$upstream exists but is not a Git checkout" }
    git clone $Url $upstream
    Assert-ZeroExit $LASTEXITCODE 'git clone failed'
}
$head = git -C $upstream rev-parse HEAD
if ($head.Trim() -ne $Commit) {
    Write-Host "Checking out pinned upstream commit $Commit (currently $head)"
    git -C $upstream fetch origin $Commit 2>$null
    if ($LASTEXITCODE -ne 0) {
        git -C $upstream fetch origin
        Assert-ZeroExit $LASTEXITCODE 'git fetch failed'
    }
    git -C $upstream checkout --detach $Commit
    Assert-ZeroExit $LASTEXITCODE 'git checkout failed'
}

& (Join-Path $PSScriptRoot 'apply_patches.ps1')

$bash = Find-GitBash
$clang = Find-LlvmMingwClang
$clangDir = Split-Path -Parent $clang
$env:PATH = "$clangDir;$env:PATH"
$env:CXX = Convert-To-MsysPath -WindowsPath $clang -Bash $bash
Write-Host "Git Bash   : $bash"
Write-Host "Compiler   : $clang"
Write-Host "CXX (MSYS) : $env:CXX"

if ($SkipUpstreamSetup) {
    Write-Host 'Skipping upstream setup (--SkipUpstreamSetup).'
    return
}

$code = Invoke-LoggedNative -FilePath (Join-Path $buildDir 'upstream_setup.log') -Body {
    Push-Location $upstream
    try { & $bash -lc 'scripts/setup.sh --native-only' }
    finally { Pop-Location }
}
Assert-ZeroExit $code 'Upstream setup failed'
Write-Host 'Setup complete. Next: scripts/build.ps1'
