# Shared helpers for the Windows build scripts. Dot-source from another script.

$ErrorActionPreference = 'Stop'

function Get-RepoRoot {
    return (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

function Find-GitBash {
    $candidates = @(
        (Join-Path $env:ProgramFiles 'Git\bin\bash.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe'),
        (Join-Path $env:USERPROFILE 'scoop\apps\git\current\bin\bash.exe')
    )
    $programFilesX86 = ${env:ProgramFiles(x86)}
    if ($programFilesX86) { $candidates += (Join-Path $programFilesX86 'Git\bin\bash.exe') }
    $found = Get-Command bash.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.Source -and $_.Source -notmatch '\\System32\\' } |
        Select-Object -First 1
    if ($found) { $candidates += $found.Source }
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    throw 'Git Bash (bash.exe) was not found. Install Git for Windows or put Git Bash on PATH.'
}

function Find-LlvmMingwClang {
    if ($env:PS2_CXX -and (Test-Path -LiteralPath $env:PS2_CXX)) { return (Resolve-Path -LiteralPath $env:PS2_CXX).Path }
    $packageRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $packageRoot) {
        $installs = Get-ChildItem -LiteralPath $packageRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like '*LLVM-MinGW*' }
        foreach ($install in $installs) {
            $hits = Get-ChildItem -LiteralPath $install.FullName -Recurse -File -Filter 'clang++.exe' -ErrorAction SilentlyContinue |
                Where-Object { $_.FullName -match 'llvm-mingw-.*-ucrt-x86_64.*\\bin\\clang\+\+\.exe$' } |
                Sort-Object LastWriteTime -Descending
            if ($hits) { return $hits[0].FullName }
        }
    }
    $found = Get-Command clang++.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) { return $found.Source }
    throw 'llvm-mingw UCRT clang++.exe was not found. Install MartinStorsjo.LLVM-MinGW.UCRT or set PS2_CXX.'
}

function Convert-To-MsysPath {
    param([Parameter(Mandatory = $true)][string]$WindowsPath, [Parameter(Mandatory = $true)][string]$Bash)
    $quoted = $WindowsPath.Replace("'", "'\\''")
    $result = & $Bash -lc "cygpath -u '$quoted'"
    if ($LASTEXITCODE -ne 0 -or -not $result) { throw "cygpath failed for $WindowsPath" }
    return ($result | Select-Object -Last 1).Trim()
}

function Invoke-LoggedNative {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(Mandatory = $true)][scriptblock]$Body
    )
    $parent = Split-Path -Parent $FilePath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $output = & $Body 2>&1
    $code = $LASTEXITCODE
    $lines = @($output | ForEach-Object { $_.ToString() })
    $lines | Set-Content -LiteralPath $FilePath -Encoding UTF8
    $lines | ForEach-Object { Write-Host $_ }
    return $code
}

function Assert-ZeroExit {
    param([int]$Code, [string]$Message)
    if ($Code -ne 0) { throw "$Message (exit $Code)" }
}
