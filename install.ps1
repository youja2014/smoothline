# smoothline — Claude Code statusline installer (Windows)
#
# Local install (from a clone or unzipped folder):
#   PowerShell -ExecutionPolicy Bypass -File .\install.ps1
#
# One-liner (downloads everything from GitHub):
#   irm https://raw.githubusercontent.com/youja2014/smoothline/main/install.ps1 | iex

$ErrorActionPreference = 'Stop'

$RepoBase = 'https://raw.githubusercontent.com/youja2014/smoothline/main'

# In one-liner (irm | iex) mode $PSScriptRoot is empty; in local mode it's the script folder.
$src = $PSScriptRoot
$dst = Join-Path $env:USERPROFILE '.claude'
New-Item -ItemType Directory -Force -Path $dst | Out-Null

function Get-Asset([string]$name, [string]$outPath) {
    if ($src -and (Test-Path (Join-Path $src $name))) {
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path $src $name))
    } else {
        $tmp = [System.IO.Path]::GetTempFileName()
        try {
            Invoke-WebRequest -Uri "$RepoBase/$name" -OutFile $tmp -UseBasicParsing
            $bytes = [System.IO.File]::ReadAllBytes($tmp)
        } finally {
            Remove-Item $tmp -ErrorAction SilentlyContinue
        }
    }
    [System.IO.File]::WriteAllBytes($outPath, $bytes)
}

Write-Host "[1/4] Installing statusline files to $dst" -ForegroundColor Cyan

# statusline.py contains UTF-8 multibyte glyphs — Get-Asset preserves raw bytes.
$pyOut  = Join-Path $dst 'statusline.py'
$ps1Out = Join-Path $dst 'statusline-command.ps1'
Get-Asset 'statusline.py'          $pyOut
Get-Asset 'statusline-command.ps1' $ps1Out

Write-Host "[2/4] Detecting python on PATH" -ForegroundColor Cyan
# Microsoft Store python aliases sit on PATH as 0-byte stubs that redirect to
# the Store instead of running. Get-Command finds them; only --version proves
# they're a real interpreter. Try `python` first, then `python3`.
$pythonPath = $null
foreach ($name in @('python', 'python3')) {
    $candidate = Get-Command $name -ErrorAction SilentlyContinue
    if (-not $candidate) { continue }
    try {
        $verOutput = & $candidate.Source --version 2>&1
        if ($LASTEXITCODE -eq 0 -and "$verOutput" -match 'Python\s+\d') {
            $pythonPath = $candidate.Source
            break
        }
    } catch {
        # alias redirect or other startup failure — try the next name
    }
}
if ($pythonPath) {
    Write-Host "    Found: $pythonPath" -ForegroundColor Green
} else {
    $pythonPath = 'python'
    Write-Warning "No working python on PATH. statusline.cmd will use the literal 'python' — install Python 3.x and disable Microsoft Store aliases under Settings > Apps > App execution aliases, then re-run this installer."
}

# Generate statusline.cmd dynamically so it points at THIS machine's python.
$pyPath = Join-Path $dst 'statusline.py'
$cmdContent = "@echo off`r`n`"$pythonPath`" `"$pyPath`"`r`n"
[System.IO.File]::WriteAllText((Join-Path $dst 'statusline.cmd'), $cmdContent, (New-Object System.Text.UTF8Encoding $false))

Write-Host "[3/4] Patching settings.json" -ForegroundColor Cyan
$settingsPath = Join-Path $dst 'settings.json'
if (Test-Path $settingsPath) {
    $raw = Get-Content -Raw -Path $settingsPath
    try {
        $settings = $raw | ConvertFrom-Json
    } catch {
        Write-Error "Existing settings.json is not valid JSON. Aborting. Fix it manually then re-run."
        exit 1
    }
} else {
    $settings = [pscustomobject]@{}
}

$statusLineValue = [pscustomobject]@{
    type    = 'command'
    command = (Join-Path $dst 'statusline.cmd')
    padding = 0
}

if ($settings.PSObject.Properties.Name -contains 'statusLine') {
    $settings.statusLine = $statusLineValue
} else {
    $settings | Add-Member -NotePropertyName 'statusLine' -NotePropertyValue $statusLineValue
}

$json = $settings | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($settingsPath, $json, (New-Object System.Text.UTF8Encoding $false))
Write-Host "    Wrote $settingsPath" -ForegroundColor Green

Write-Host "[4/4] Smoke test" -ForegroundColor Cyan
$testJson = '{"model":{"display_name":"Claude Opus 4.7"},"workspace":{"current_dir":"' + ($env:USERPROFILE -replace '\\','\\') + '"},"context_window":{"used_percentage":42}}'
$out = $testJson | & (Join-Path $dst 'statusline.cmd')
if ($out) {
    Write-Host "    Output: $out" -ForegroundColor Green
} else {
    Write-Warning "    Statusline produced no output. Check python install."
}

Write-Host ""
Write-Host "Done. Restart Claude Code to see the statusline." -ForegroundColor Green
