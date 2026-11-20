[CmdletBinding()]
param(
    [int]$Frames = 6000,
    [switch]$SkipOcr
)

. (Join-Path $PSScriptRoot 'common.ps1')

$repo = Get-RepoRoot
$upstream = Join-Path $repo 'third_party\ps2-native-recomp'
$runner = Join-Path $upstream 'build\native-roadrage\ps2run.exe'
$disc = Join-Path $upstream 'games\roadrage\disc.iso'
$gameDir = Join-Path $upstream 'games\roadrage'
$shots = Join-Path $repo 'analysis\shots_verify'
foreach ($file in @($runner, $disc)) {
    if (-not (Test-Path -LiteralPath $file)) { throw "Missing runtime input: $file" }
}
New-Item -ItemType Directory -Force -Path $shots | Out-Null
Get-ChildItem -LiteralPath $shots -File -ErrorAction SilentlyContinue | Remove-Item -Force

$presses = @(
    '--press 1800:start:8', '--press 2100:cross:8', '--press 2400:start:8',
    '--press 2700:cross:8', '--press 3100:cross:8', '--press 3400:cross:8',
    '--press 3700:cross:8', '--press 4000:start:8', '--press 4300:cross:8',
    '--press 4600:cross:8', '--press 4900:start:8', '--press 5200:cross:8',
    '--press 5500:cross:8'
)
Write-Host 'Running scripted boot-to-gameplay verification...'
$code = Invoke-LoggedNative -FilePath (Join-Path $repo 'analysis\run_verify.log') -Body {
    & $runner --disc $disc --game-dir $gameDir --frames $Frames --frames-dir $shots --frame-every 200 --no-record @presses
}
Assert-ZeroExit $code 'ps2run verification run failed'

python (Join-Path $repo 'tools\frame_stats.py') $shots --csv (Join-Path $repo 'analysis\frame_stats_verify.csv')
Assert-ZeroExit $LASTEXITCODE 'frame statistics failed'

if (-not $SkipOcr) {
    $ocrScript = Join-Path $repo 'tools\ocr_frame.ps1'
    $upscaled = Join-Path $shots 'upscaled'
    New-Item -ItemType Directory -Force -Path $upscaled | Out-Null
    $results = [System.Collections.Generic.List[string]]::new()
    foreach ($frame in @(2000, 2500, 2800, 3200, 3600, 3800, 6000)) {
        if ($frame -gt $Frames) { continue }
        $ppm = Join-Path $shots ('frame_{0:D5}.ppm' -f $frame)
        if (-not (Test-Path -LiteralPath $ppm)) { continue }
        $png = Join-Path $upscaled ('frame_{0:D5}.png' -f $frame)
        python -c "from PIL import Image,ImageEnhance,ImageFilter; im=Image.open(r'$ppm').convert('RGB'); im=im.resize((im.width*3,im.height*3),Image.Resampling.LANCZOS).filter(ImageFilter.SHARPEN); ImageEnhance.Contrast(im).enhance(1.5).save(r'$png')"
        if ($LASTEXITCODE -ne 0) { continue }
        $results.Add("=== frame $frame")
        $results.AddRange(@(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ocrScript -Path $png))
    }
    $results | Set-Content -LiteralPath (Join-Path $repo 'analysis\runtime_ocr.txt') -Encoding UTF8
    Write-Host 'OCR written to analysis/runtime_ocr.txt'
}
Write-Host 'Verification complete. Evidence is under analysis/.'
