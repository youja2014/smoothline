# smoothline

> Smooth, gradient statusline for Claude Code — context window + Pro/Max 5h/7d rate-limit bars (Windows / macOS / Linux)

**[English](README.md)** | **한국어**

---

[Claude Code](https://claude.com/claude-code) 의 statusline 을 부드러운 그라디언트 바와 Pro/Max rate-limit 표시까지 확장한 패키지. **Windows / macOS / Linux 모두 지원**.

| OS | 인스톨러 | 동작 방식 |
|---|---|---|
| Windows | `install.cmd` (또는 `install.ps1`) | `statusline.cmd` 가 Python 호출 |
| macOS / Linux | `install.sh` | `statusline.py` 가 shebang 으로 직접 실행 |

핵심 로직(`statusline.py`)은 모든 OS에서 같은 파일. 인스톨러만 OS별로 분기하고, `~/.claude/settings.json` 의 `statusLine.command` 를 OS 에 맞는 진입점으로 자동 셋업합니다.

---

## 결과물 미리보기

```
youja@HOSTNAME ~/workspace │ ⎇ main │ Claude Opus 4.7 │ ctx [████▏      ] 42% │ 5h [██▏     ] 28% ↻3h11m │ 7d [▉       ] 12% ↻4d23h
```

- `user@host` + 현재 디렉토리(홈은 `~`)
- git 브랜치 (있으면)
- 모델 이름
- `ctx` — 현재 세션 컨텍스트 윈도우 사용률 (10칸 바)
- `5h` — Claude **Pro/Max 5시간 롤링 윈도우** 사용률 + 다음 리셋까지 남은 시간 `↻Xh Ym` (8칸 바)
- `7d` — Claude **Pro/Max 7일 롤링 윈도우** 사용률 + 다음 리셋까지 남은 시간 `↻Xd` (8칸 바)

모든 바는 1/8 단위 스무스 바 + 사용률에 따라 초록→노랑→빨강 그라디언트.

> **`5h` / `7d` 표시 조건**: Claude.ai Pro/Max 구독자 한정. 첫 API 응답 이후부터 statusline JSON에 `rate_limits.five_hour.*` / `rate_limits.seven_day.*` 가 포함됨 (Anthropic 공식 statusline 스키마). API 키 사용자거나 첫 메시지 전에는 이 두 청크는 자동으로 숨겨짐.

렌더링은 stdin JSON 1회 처리만 하고 git은 `.git/HEAD`를 직접 읽어서 매 프롬프트마다 git 프로세스를 띄우지 않음.

---

## 0. 사전 요구사항

- **Python 3.x** — `statusline.py` 가 실행되어야 함. 어떤 Python 이든 OK.
  - Windows: `python` 또는 `python.exe` 가 PATH 또는 `statusline.cmd` 에 명시한 절대 경로로 호출 가능해야 함
  - macOS/Linux: `python3` 또는 `python` 가 PATH 에 있어야 함 (`install.sh` 가 자동 탐색)
- 터미널이 **truecolor (24-bit) ANSI** 지원해야 그라디언트가 보임. Windows Terminal / iTerm2 / 최신 GNOME Terminal 등 OK.

Python 경로 확인:
```bash
# Windows (PowerShell)
where.exe python
# macOS / Linux
which python3 || which python
```

---

## 1. 파일 3개 생성

위치: `%USERPROFILE%\.claude\` (예: `C:\Users\<USERNAME>\.claude\`)

### 1-A. `statusline.cmd`

> **수정 포인트**: Python 실행 파일 경로를 새 PC 환경에 맞게 변경. 시스템 PATH에 python이 있다면 그냥 `python`만 써도 됨.

```cmd
@echo off
"%USERPROFILE%\AppData\Roaming\uv\python\cpython-3.14-windows-x86_64-none\python.exe" "%USERPROFILE%\.claude\statusline.py"
```

옵션 — PATH의 python 사용:
```cmd
@echo off
python "%USERPROFILE%\.claude\statusline.py"
```

### 1-B. `statusline.py`

> 패키지에 포함된 `statusline.py` 를 그대로 사용하세요. 아래는 참고용 전체 소스 (Pro/Max `rate_limits` 표시 포함). 직접 보고 싶을 때만 펼쳐보면 됩니다 — 설치는 zip 안 파일이 정본입니다.

> **인코딩 주의**: `statusline.py`는 반드시 **UTF-8 (BOM 없음)** 으로 저장. PowerShell의 `Set-Content`/`Out-File` 기본은 UTF-16 LE라 깨짐. 아래 "한 번에 설치하기" 섹션의 스크립트를 쓰면 안전.

### 1-C. `statusline-command.ps1` (선택)

Python 없이 PowerShell만으로 동작하는 폴백 버전. 색상/스무스 바 없고 ASCII만. 평소엔 안 써도 되지만 Python 설치 안 된 PC를 위한 백업.

```powershell
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
if ($branch) { $parts += "git:$branch" }
if ($model)  { $parts += $model }

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
```

---

## 2. `settings.json` 등록 (인스톨러가 자동 처리)

인스톨러가 `~/.claude/settings.json` 의 `statusLine` 키를 자동으로 추가/병합. 기존 키 보존.

수동 설치 시 OS 별 등록값:

**Windows** — `%USERPROFILE%\.claude\settings.json`
```json
{
  "statusLine": {
    "type": "command",
    "command": "C:\\Users\\<USERNAME>\\.claude\\statusline.cmd",
    "padding": 0
  }
}
```

**macOS / Linux** — `~/.claude/settings.json`
```json
{
  "statusLine": {
    "type": "command",
    "command": "/Users/<USERNAME>/.claude/statusline.py",
    "padding": 0
  }
}
```

> `<USERNAME>` 자리에 실제 사용자명 넣기. macOS/Linux 는 `statusline.py` 자체가 `chmod +x` 되어있고 shebang(`#!/usr/bin/env python3`) 으로 직접 실행 가능하므로 wrapper 불필요.

---

## 3. 한 번에 설치하기

### 3-A. 한 줄 설치 (가장 빠름)

인스톨러가 GitHub 에서 필요한 파일을 직접 받아 `~/.claude/` 에 깔고 `settings.json` 까지 패치합니다.

#### macOS / Linux
```bash
curl -fsSL https://raw.githubusercontent.com/youja2014/smoothline/main/install.sh | bash
```

#### Windows (PowerShell)
```powershell
irm https://raw.githubusercontent.com/youja2014/smoothline/main/install.ps1 | iex
```

#### Windows (cmd)
```cmd
curl -fsSL https://raw.githubusercontent.com/youja2014/smoothline/main/install.cmd -o install.cmd && install.cmd && del install.cmd
```

### 3-B. git clone / zip 으로 설치

소스를 받아 인스톨러를 로컬 모드로 실행. 같은 폴더의 sibling 파일을 그대로 복사하므로 네트워크 없이도 동작.

#### Windows
```cmd
install.cmd       :: 더블클릭으로 OK
```
또는 PowerShell:
```powershell
.\install.ps1
```

#### macOS / Linux
```bash
bash install.sh
# 또는
chmod +x install.sh && ./install.sh
```

#### Claude Code 안에서 설치 (Mac/Linux)
clone/unzip 한 PC 에서 Claude Code 를 띄우고 폴더로 `cd` 한 뒤 이렇게 말하면 됩니다:
> "이 폴더의 install.sh 실행해서 statusline 설치해줘"

### 인스톨러 공통 동작
1. **파일 확보** — sibling 에 `statusline.py` 가 있으면 그걸 복사 (로컬 모드), 없으면 GitHub raw URL 에서 다운로드 (한 줄 설치 모드)
2. Python 위치 자동 탐색 — Windows 는 PATH 의 `python`, Unix 는 `python3` → `python` 순
3. Windows 는 검출된 python 절대 경로로 `statusline.cmd` 를 **동적 생성** (한 줄 설치 직후 별도 편집 없이 바로 동작)
4. `~/.claude/settings.json` 의 `statusLine` 키만 추가/교체 (다른 키는 보존)
5. 더미 JSON 으로 statusline 한 번 실행해서 결과를 화면에 보여줌

---

## 4. 동작 확인

설치 직후 인스톨러가 출력을 보여주므로 별도 작업 불필요. 직접 다시 확인하려면:

**Windows (PowerShell)**
```powershell
$json = '{"model":{"display_name":"Claude Opus 4.7"},"workspace":{"current_dir":"D:\\workspace"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":28,"resets_at":2000000000},"seven_day":{"used_percentage":12,"resets_at":2000300000}}}'
$tmp = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding $false))
& cmd /c "type `"$tmp`" | `"$env:USERPROFILE\.claude\statusline.cmd`""
Remove-Item $tmp
```
> PowerShell 에서 직접 `'{...}' | statusline.cmd` 로 파이프하면 UTF-16 LE 로 인코딩되어 Python 의 JSON 파서가 실패함. tempfile 경유가 안전.

**macOS / Linux (bash)**
```bash
NOW=$(date +%s)
echo '{"model":{"display_name":"Claude Opus 4.7"},"workspace":{"current_dir":"'"$HOME"'"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":28,"resets_at":'$((NOW+11600))'},"seven_day":{"used_percentage":12,"resets_at":'$((NOW+424600))'}}}' \
  | "$HOME/.claude/statusline.py"
```

색상 포함 두 줄이 출력되면 성공. 그 후 Claude Code 를 새로 실행하면 statusline 이 적용됨.

---

## 5. 트러블슈팅

| 증상 | 원인 / 조치 |
|---|---|
| 한글/이모지가 깨짐 | `statusline.py` 가 UTF-16 또는 CP949 로 저장됨. UTF-8(BOM 없음)으로 다시 저장. |
| 색상 코드(`[38;2;...m`)가 그대로 보임 | 터미널이 ANSI truecolor 미지원. Windows Terminal / iTerm2 / 최신 GNOME Terminal 로 전환. |
| `'python' is not recognized` (Win) / `python3: command not found` (Unix) | Python 이 PATH 에 없음. Windows 는 `statusline.cmd` 에서 절대 경로로 지정. macOS 는 `brew install python` 또는 [python.org](https://www.python.org) 인스톨러. Linux 는 배포판 패키지 매니저로 설치. |
| statusline 이 아예 안 뜸 | `settings.json` 의 `command` 경로 오타 확인. 4번 수동 실행으로 디버그. macOS/Linux 는 `chmod +x ~/.claude/statusline.py` 도 확인. |
| `bar character` 가 칸 어긋남 | 폰트가 Powerline/유니코드 박스 미지원. Cascadia Mono / JetBrains Mono / Menlo 등으로 변경. |
| Linux 에서 `Permission denied` | `chmod +x ~/.claude/statusline.py` 누락. 인스톨러를 다시 돌리거나 직접 실행. |

---

## 6. 커스터마이즈 포인트

- 바 너비: `main()` 안의 `render_usage(...)` 호출에 넘기는 4번째 인자 (`ctx` 10, `5h`/`7d` 8)
- 색상: `GRAY/BLUE/PURPLE/ORANGE/SEP` RGB 튜플
- 그라디언트 임계: `gradient_color()` 의 `green/yellow/red`
- 표시 항목 순서: `chunks.append(...)` 순서 변경
- 5h / 7d 청크 숨기기: 해당 `render_usage(...)` 호출만 주석 처리
- 리셋 시간 표기 끄기: `render_usage()` 의 `resets_at` 인자에 `None` 전달
