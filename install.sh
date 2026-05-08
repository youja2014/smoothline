#!/usr/bin/env bash
# Claude Code statusline installer (macOS / Linux)
# Usage:
#   bash install.sh
# or make executable:
#   chmod +x install.sh && ./install.sh
set -euo pipefail

SRC_DIR="$(cd "$(dirname "$0")" && pwd)"
DST_DIR="$HOME/.claude"
mkdir -p "$DST_DIR"

c_cyan='\033[36m'; c_green='\033[32m'; c_yellow='\033[33m'; c_red='\033[31m'; c_reset='\033[0m'

printf "${c_cyan}[1/4]${c_reset} Copying statusline.py to %s\n" "$DST_DIR"
cp "$SRC_DIR/statusline.py" "$DST_DIR/statusline.py"
chmod +x "$DST_DIR/statusline.py"

printf "${c_cyan}[2/4]${c_reset} Locating python\n"
PY=""
for cand in python3 python; do
    if command -v "$cand" >/dev/null 2>&1; then
        PY="$(command -v "$cand")"
        break
    fi
done
if [ -z "$PY" ]; then
    printf "${c_red}ERROR:${c_reset} python3/python not found on PATH. Install Python 3.x first.\n" >&2
    exit 1
fi
printf "    Using: %s\n" "$PY"

# settings.json command field — point directly at the executable .py
# (works because of the shebang + chmod +x above)
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
