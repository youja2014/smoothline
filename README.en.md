# smoothline

> Smooth, gradient statusline for Claude Code — context window + Pro/Max 5h/7d rate-limit bars (Windows / macOS / Linux)

**English** | **[한국어](README.md)**

---

A drop-in statusline for [Claude Code](https://claude.com/claude-code) that ships the same look across **Windows, macOS, and Linux**.

| OS | Installer | How it runs |
|---|---|---|
| Windows | `install.cmd` (or `install.ps1`) | `statusline.cmd` invokes Python |
| macOS / Linux | `install.sh` | `statusline.py` runs directly via shebang |

The core renderer (`statusline.py`) is identical on every OS. Only the installer branches per OS, and `~/.claude/settings.json`'s `statusLine.command` is wired to the right entry point automatically.

---

## Preview

```
youja@HOSTNAME ~/workspace │ ⎇ main │ Claude Opus 4.7 │ ctx [████▏      ] 42% │ 5h [██▏     ] 28% ↻3h11m │ 7d [▉       ] 12% ↻4d23h
```

- `user@host` + current directory (home shown as `~`)
- git branch (when present)
- model name
- `ctx` — context window usage of the current session (10-cell bar)
- `5h` — Claude **Pro/Max 5-hour rolling window** usage + time until reset `↻Xh Ym` (8-cell bar)
- `7d` — Claude **Pro/Max 7-day rolling window** usage + time until reset `↻Xd` (8-cell bar)

All bars use 1/8-cell smooth Unicode glyphs and a green→yellow→red gradient that follows the percentage.

> **When `5h` / `7d` show up**: only for Claude.ai Pro/Max subscribers. After the first API response, the statusline JSON includes `rate_limits.five_hour.*` / `rate_limits.seven_day.*` (per Anthropic's official statusline schema). For API-key users, or before the first message, those two chunks are hidden automatically.

The renderer parses stdin JSON once and reads `.git/HEAD` directly — no `git` subprocess per prompt.

---

## 0. Prerequisites

- **Python 3.x** — required to run `statusline.py`. Any Python build works.
  - Windows: `python` / `python.exe` must be reachable on PATH, or set the absolute path inside `statusline.cmd`
  - macOS/Linux: `python3` or `python` must be on PATH (`install.sh` discovers this automatically)
- A terminal with **truecolor (24-bit) ANSI** support so the gradient renders. Windows Terminal / iTerm2 / recent GNOME Terminal / etc. all qualify.

Verify Python:
```bash
# Windows (PowerShell)
where.exe python
# macOS / Linux
which python3 || which python
```

---

## 1. The three files

Destination: `%USERPROFILE%\.claude\` (e.g. `C:\Users\<USERNAME>\.claude\`) on Windows, `~/.claude/` elsewhere.

### 1-A. `statusline.cmd` (Windows only)

> **Tweak point**: point this at the Python executable on the new machine. If `python` is on PATH, just use `python`.

```cmd
@echo off
"%USERPROFILE%\AppData\Roaming\uv\python\cpython-3.14-windows-x86_64-none\python.exe" "%USERPROFILE%\.claude\statusline.py"
```

PATH-based variant:
```cmd
@echo off
python "%USERPROFILE%\.claude\statusline.py"
```

### 1-B. `statusline.py`

> Use the `statusline.py` shipped in this package as-is. The full source (Pro/Max `rate_limits` rendering included) lives in the file — the installer wires up the canonical copy.

> **Encoding note**: `statusline.py` must be saved as **UTF-8 (no BOM)**. PowerShell's default for `Set-Content` / `Out-File` is UTF-16 LE, which corrupts it. The "One-shot install" section below handles this safely.

### 1-C. `statusline-command.ps1` (optional)

A pure-PowerShell fallback. No colors, no smooth bars, ASCII only. You don't normally need it — keep it as a backup for machines without Python installed.

---

## 2. Registering in `settings.json` (the installer does this for you)

The installer adds/merges the `statusLine` key into `~/.claude/settings.json`, preserving any other keys.

If you wire it up by hand, here is what the OS-specific entry looks like:

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

> Replace `<USERNAME>`. On macOS/Linux, `statusline.py` is `chmod +x`'d and has a `#!/usr/bin/env python3` shebang, so it runs directly — no wrapper needed.

---

## 3. One-shot install (recommended)

Unzip / clone the package and run the installer for your OS:

### Windows
```cmd
install.cmd       :: double-click works
```
or PowerShell:
```powershell
.\install.ps1
```

### macOS / Linux
```bash
bash install.sh
# or
chmod +x install.sh && ./install.sh
```

### Inside Claude Code (macOS/Linux)
On a machine that already has Claude Code, `cd` into the unpacked folder and just say:
> "Run install.sh in this folder to set up the statusline"

Claude will invoke `bash install.sh` (PATH-based python discovery, settings.json patch, smoke test — all included).

### What every installer does
1. Copies the statusline files into `~/.claude/`
2. Auto-detects Python — Windows checks `python` on PATH, Unix tries `python3` then `python`
3. Adds/replaces only the `statusLine` key in `~/.claude/settings.json` (other keys are preserved)
4. Runs the statusline once with a dummy JSON payload and prints the output

---

## 4. Verifying

The installer prints sample output, so usually you don't need to do anything. To re-run the check:

**Windows (PowerShell)**
```powershell
$json = '{"model":{"display_name":"Claude Opus 4.7"},"workspace":{"current_dir":"D:\\workspace"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":28,"resets_at":2000000000},"seven_day":{"used_percentage":12,"resets_at":2000300000}}}'
$tmp = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding $false))
& cmd /c "type `"$tmp`" | `"$env:USERPROFILE\.claude\statusline.cmd`""
Remove-Item $tmp
```
> Piping `'{...}' | statusline.cmd` directly in PowerShell encodes as UTF-16 LE and breaks Python's JSON parser. Going through a tempfile is the safe path.

**macOS / Linux (bash)**
```bash
NOW=$(date +%s)
echo '{"model":{"display_name":"Claude Opus 4.7"},"workspace":{"current_dir":"'"$HOME"'"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":28,"resets_at":'$((NOW+11600))'},"seven_day":{"used_percentage":12,"resets_at":'$((NOW+424600))'}}}' \
  | "$HOME/.claude/statusline.py"
```

You should see two colored lines. After that, restart Claude Code — the new statusline shows up immediately.

---

## 5. Troubleshooting

| Symptom | Cause / Fix |
|---|---|
| Korean / emoji garbled | `statusline.py` was saved as UTF-16 or CP949. Re-save as UTF-8 (no BOM). |
| Raw color codes (`[38;2;...m`) visible | Terminal lacks ANSI truecolor. Switch to Windows Terminal / iTerm2 / recent GNOME Terminal. |
| `'python' is not recognized` (Win) / `python3: command not found` (Unix) | Python not on PATH. On Windows, hard-code the absolute path inside `statusline.cmd`. On macOS, `brew install python` or use [python.org](https://www.python.org). On Linux, use the distro's package manager. |
| Statusline doesn't show at all | Verify the `command` path in `settings.json`. Run section 4 manually to debug. On macOS/Linux, check `chmod +x ~/.claude/statusline.py`. |
| Bar glyphs out of alignment | Font lacks Powerline / Unicode box characters. Switch to Cascadia Mono / JetBrains Mono / Menlo. |
| `Permission denied` on Linux | `chmod +x ~/.claude/statusline.py` was skipped. Re-run the installer or fix it manually. |

---

## 6. Customization

- Bar width: the 4th argument to each `render_usage(...)` call inside `main()` (`ctx` is 10, `5h`/`7d` are 8)
- Colors: `GRAY / BLUE / PURPLE / ORANGE / SEP` RGB tuples
- Gradient breakpoints: `green / yellow / red` inside `gradient_color()`
- Display order: reorder how `line1` / `line2` chunks are appended
- Hide the 5h / 7d chunks: comment out their `render_usage(...)` calls
- Drop the reset-time tail: pass `None` as the `resets_at` argument to `render_usage()`

---

## License

[MIT](LICENSE)
