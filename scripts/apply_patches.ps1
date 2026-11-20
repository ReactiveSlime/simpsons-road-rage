[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'common.ps1')

$repo = Get-RepoRoot
$upstream = Join-Path $repo 'third_party\ps2-native-recomp'
$patchDir = Join-Path $repo 'patches'

if (-not (Test-Path -LiteralPath (Join-Path $upstream '.git'))) {
    throw "Upstream checkout is missing: $upstream (run scripts/setup.ps1 first)"
}
if (-not (Test-Path -LiteralPath $patchDir)) { return }

foreach ($patch in Get-ChildItem -LiteralPath $patchDir -Filter '*.patch' -File | Sort-Object Name) {
    # Idempotent: a reverse check succeeds when the patch is already present.
    git -C $upstream apply --check --reverse $patch.FullName 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Patch already applied: $($patch.Name)"
        continue
    }

    git -C $upstream apply $patch.FullName
    Assert-ZeroExit $LASTEXITCODE "Failed to apply $($patch.FullName)"
    Write-Host "Applied patch: $($patch.Name)"
}
