[CmdletBinding()]
param([string]$Iso)

. (Join-Path $PSScriptRoot 'common.ps1')

$repo = Get-RepoRoot
Write-Host 'Running tool regression tests...'
python -m unittest discover -s (Join-Path $repo 'tests') -v
Assert-ZeroExit $LASTEXITCODE 'Tool regression tests failed'

if ($Iso) {
    $buildDir = Join-Path $repo 'build'
    if (-not (Test-Path -LiteralPath $buildDir)) { New-Item -ItemType Directory -Force -Path $buildDir | Out-Null }
    Write-Host "Validating supplied image: $Iso"
    python (Join-Path $repo 'tools\validate_iso.py') --iso $Iso --json (Join-Path $buildDir 'iso_validation.json')
    Assert-ZeroExit $LASTEXITCODE 'ISO validation failed'
}
Write-Host 'All checks passed.'
