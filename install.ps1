# Claude Code statusline installer
# Run from the unzipped folder: PowerShell -ExecutionPolicy Bypass -File .\install.ps1

$ErrorActionPreference = 'Stop'

$src = $PSScriptRoot
$dst = Join-Path $env:USERPROFILE '.claude'
New-Item -ItemType Directory -Force -Path $dst | Out-Null

Write-Host "[1/4] Copying statusline files to $dst" -ForegroundColor Cyan

# .cmd is ASCII-safe, plain copy
Copy-Item -Path (Join-Path $src 'statusline.cmd') -Destination (Join-Path $dst 'statusline.cmd') -Force

# .ps1 is ASCII-safe, plain copy
Copy-Item -Path (Join-Path $src 'statusline-command.ps1') -Destination (Join-Path $dst 'statusline-command.ps1') -Force

# .py contains UTF-8 multibyte (box-drawing chars). Read raw bytes and write
# verbatim to avoid any re-encoding by PowerShell.
$pyBytes = [System.IO.File]::ReadAllBytes((Join-Path $src 'statusline.py'))
[System.IO.File]::WriteAllBytes((Join-Path $dst 'statusline.py'), $pyBytes)

Write-Host "[2/4] Checking python on PATH" -ForegroundColor Cyan
$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    Write-Warning "python not found on PATH. Install Python 3.x or edit statusline.cmd to point at python.exe absolute path."
} else {
    Write-Host "    Found: $($py.Source)" -ForegroundColor Green
}

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
    Write-Warning "    Statusline produced no output. Check python install / statusline.cmd contents."
}

Write-Host ""
Write-Host "Done. Restart Claude Code to see the statusline." -ForegroundColor Green
