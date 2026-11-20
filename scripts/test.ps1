[CmdletBinding()]
param([string]$Iso)

. (Join-Path $PSScriptRoot 'common.ps1')

$repo = Get-RepoRoot
Write-Host 'Running tool regression tests...'
python -m unittest discover -s (Join-Path $repo 'tests') -v
Assert-ZeroExit $LASTEXITCODE 'Tool regression tests failed'

if ($Iso) {
    Write-Host "Validating supplied image: $Iso"
    python (Join-Path $repo 'tools\validate_iso.py') --iso $Iso --json (Join-Path $repo 'analysis\iso_validation.json')
    Assert-ZeroExit $LASTEXITCODE 'ISO validation failed'
}
Write-Host 'All checks passed.'
