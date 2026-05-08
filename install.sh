#!/usr/bin/env bash
# smoothline — Claude Code statusline installer (macOS / Linux)
#
# Local install (from a clone or unzipped folder):
#   bash install.sh
#
# One-liner (downloads everything from GitHub):
#   curl -fsSL https://raw.githubusercontent.com/youja2014/smoothline/main/install.sh | bash
set -euo pipefail

REPO_BASE="https://raw.githubusercontent.com/youja2014/smoothline/main"
DST_DIR="$HOME/.claude"
mkdir -p "$DST_DIR"

c_cyan='\033[36m'; c_green='\033[32m'; c_yellow='\033[33m'; c_red='\033[31m'; c_reset='\033[0m'

# Detect mode: SRC_DIR is set only when running from a real script file with siblings.
# In curl-pipe mode BASH_SOURCE[0] is empty / 'main' / non-existent, so SRC_DIR stays empty.
SRC_DIR=""
if [ -n "${BASH_SOURCE-}" ]; then
    candidate="${BASH_SOURCE[0]:-}"
    if [ -n "$candidate" ] && [ -f "$candidate" ]; then
        SRC_DIR="$(cd "$(dirname "$candidate")" && pwd)"
    fi
fi

fetch_asset() {
    local name="$1"
    local out="$2"
    if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/$name" ]; then
        cp "$SRC_DIR/$name" "$out"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL "$REPO_BASE/$name" -o "$out"
    elif command -v wget >/dev/null 2>&1; then
        wget -q "$REPO_BASE/$name" -O "$out"
    else
        printf "${c_red}ERROR:${c_reset} curl or wget is required to download %s\n" "$name" >&2
        exit 1
    fi
}

printf "${c_cyan}[1/4]${c_reset} Installing statusline.py to %s\n" "$DST_DIR"
fetch_asset "statusline.py" "$DST_DIR/statusline.py"
chmod +x "$DST_DIR/statusline.py"

printf "${c_cyan}[2/4]${c_reset} Locating python\n"
PY=""
for cand in python3 python; do
    if command -v "$cand" >/dev/null 2>&1; then
        candidate="$(command -v "$cand")"
        # Verify the binary actually runs. On Windows, `python3` and `python`
        # are often Microsoft Store execution aliases — 0-byte stubs that show
        # up on PATH but redirect to the Store instead of executing. A real
        # interpreter answers --version; an alias does not.
        if "$candidate" --version >/dev/null 2>&1; then
            PY="$candidate"
            break
        fi
    fi
done
if [ -z "$PY" ]; then
    printf "${c_red}ERROR:${c_reset} no working python3/python on PATH. Install Python 3.x (and on Windows, disable the Microsoft Store python aliases under Settings > Apps > App execution aliases).\n" >&2
    exit 1
fi
printf "    Using: %s\n" "$PY"

STATUSLINE_CMD="$DST_DIR/statusline.py"

printf "${c_cyan}[3/4]${c_reset} Patching %s/settings.json\n" "$DST_DIR"
"$PY" - "$DST_DIR/settings.json" "$STATUSLINE_CMD" <<'PYEOF'
import json
import sys
from pathlib import Path

settings_path = Path(sys.argv[1])
cmd = sys.argv[2]

if settings_path.exists():
    try:
        data = json.loads(settings_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"ERROR: existing settings.json is not valid JSON: {e}", file=sys.stderr)
        sys.exit(1)
    if not isinstance(data, dict):
        print("ERROR: settings.json root must be an object", file=sys.stderr)
        sys.exit(1)
else:
    data = {}

data["statusLine"] = {
    "type": "command",
    "command": cmd,
    "padding": 0,
}

settings_path.write_text(
    json.dumps(data, indent=2, ensure_ascii=False) + "\n",
    encoding="utf-8",
)
print(f"    Wrote {settings_path}")
PYEOF

printf "${c_cyan}[4/4]${c_reset} Smoke test\n"
NOW=$(date +%s)
RESET_5H=$((NOW + 11600))
RESET_7D=$((NOW + 424600))
SAMPLE=$(cat <<JSON
{"model":{"display_name":"Claude Opus 4.7"},"workspace":{"current_dir":"$HOME"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":28,"resets_at":$RESET_5H},"seven_day":{"used_percentage":12,"resets_at":$RESET_7D}}}
JSON
)
OUT="$(printf '%s' "$SAMPLE" | "$PY" "$DST_DIR/statusline.py")"
if [ -n "$OUT" ]; then
    printf "    Output:\n"
    printf '%s\n' "$OUT" | sed 's/^/      /'
else
    printf "${c_yellow}    WARN:${c_reset} statusline produced no output. Check python install.\n"
fi

printf "\n${c_green}Done.${c_reset} Restart Claude Code to see the statusline.\n"
