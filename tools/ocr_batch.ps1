param([Parameter(Mandatory = $true)][string[]]$Path)

foreach ($item in $Path) {
    Write-Output "=== $([System.IO.Path]::GetFileName($item))"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'ocr_frame.ps1') -Path $item
}
