$input_data = $input | Out-String
$json = $input_data | ConvertFrom-Json

$model    = $json.model.display_name
$cwd      = $json.workspace.current_dir
$used_pct = $json.context_window.used_percentage

$home_dir = $env:USERPROFILE -replace '\\', '/'
$cwd_norm = $cwd -replace '\\', '/'
$cwd_display = $cwd_norm -replace [regex]::Escape($home_dir), '~'

$user     = $env:USERNAME
$hostname = $env:COMPUTERNAME

# Git branch detection (read .git/HEAD directly — no git spawn per render)
$branch = $null
if ($cwd) {
    $cur = $cwd
    while ($cur) {
        $dotGit = Join-Path $cur '.git'
        if (Test-Path $dotGit) {
            $gitDir = $null
            if (Test-Path -PathType Container $dotGit) {
                $gitDir = $dotGit
            } else {
                $content = Get-Content $dotGit -Raw -ErrorAction SilentlyContinue
                if ($content -match 'gitdir:\s*(.+)') {
                    $resolved = $matches[1].Trim()
                    if (-not [System.IO.Path]::IsPathRooted($resolved)) {
                        $resolved = Join-Path $cur $resolved
                    }
                    $gitDir = $resolved
                }
            }
            if ($gitDir) {
                $headPath = Join-Path $gitDir 'HEAD'
                if (Test-Path $headPath) {
                    $head = (Get-Content $headPath -Raw -ErrorAction SilentlyContinue).Trim()
                    if ($head -match '^ref:\s*refs/heads/(.+)$') {
                        $branch = $matches[1].Trim()
                    } elseif ($head.Length -ge 7) {
                        $branch = $head.Substring(0, 7)
                    }
                }
            }
            break
        }
        $parent = Split-Path $cur -Parent
        if (-not $parent -or $parent -eq $cur) { break }
        $cur = $parent
    }
}

$parts = @("${user}@${hostname} ${cwd_display}")

if ($branch) {
    $parts += "git:$branch"
}

if ($model) {
    $parts += $model
}

if ($null -ne $used_pct) {
    $pct_int = [int][math]::Round($used_pct)
    if ($pct_int -lt 0)   { $pct_int = 0 }
    if ($pct_int -gt 100) { $pct_int = 100 }
    $width  = 10
    $filled = [int][math]::Round(($pct_int / 100.0) * $width)
    $bar    = ('#' * $filled) + ('-' * ($width - $filled))
    $parts += "[$bar] ${pct_int}%"
}

$parts -join ' | '
