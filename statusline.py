#!/usr/bin/env python3
import json
import os
import socket
import sys
from datetime import datetime, timezone
from pathlib import Path


def _ensure_utf8_stdout() -> None:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient_color(pct: float):
    green = (0x4A, 0xDE, 0x80)
    yellow = (0xFA, 0xCC, 0x15)
    red = (0xEF, 0x44, 0x44)
    p = max(0.0, min(1.0, pct / 100.0))
    if p < 0.5:
        return lerp(green, yellow, p * 2)
    return lerp(yellow, red, (p - 0.5) * 2)


def fg(rgb) -> str:
    r, g, b = rgb
    return f"\x1b[38;2;{r};{g};{b}m"


def reset() -> str:
    return "\x1b[0m"


def smooth_bar(pct: float, width: int = 12) -> str:
    parts = " ▏▎▍▌▋▊▉█"
    eighths = pct / 100.0 * width * 8
    full = int(eighths // 8)
    rem = int(eighths % 8)
    if full >= width:
        return "█" * width
    return "█" * full + parts[rem] + " " * (width - full - 1)


def find_branch(cwd: str):
    if not cwd:
        return None
    try:
        cur = Path(cwd).resolve()
    except OSError:
        return None
    for parent in [cur] + list(cur.parents):
        gitp = parent / ".git"
        if not gitp.exists():
            continue
        if gitp.is_dir():
            git_dir = gitp
        else:
            try:
                content = gitp.read_text(encoding="utf-8", errors="replace")
            except OSError:
                return None
            git_dir = None
            for line in content.splitlines():
                if line.startswith("gitdir:"):
                    p = line.split(":", 1)[1].strip()
                    gd = Path(p)
                    if not gd.is_absolute():
                        gd = (parent / p)
                    git_dir = gd
                    break
            if git_dir is None:
                return None
        head = git_dir / "HEAD"
        if not head.exists():
            return None
        try:
            text = head.read_text(encoding="utf-8", errors="replace").strip()
        except OSError:
            return None
        ref_prefix = "ref: refs/heads/"
        if text.startswith(ref_prefix):
            return text[len(ref_prefix):]
        if len(text) >= 7:
            return text[:7]
        return None
    return None


def shorten_cwd(cwd: str) -> str:
    if not cwd:
        return ""
    home = os.path.expanduser("~").replace("\\", "/")
    disp = cwd.replace("\\", "/")
    if home and disp.lower().startswith(home.lower()):
        disp = "~" + disp[len(home):]
    return disp


def relative_reset(value):
    """Parse reset timestamp (ISO-8601 string, or unix int/float in seconds or ms),
    return short relative remaining like '2h13m' / '3d4h' / '45m'."""
    if value is None or value == "":
        return None
    try:
        if isinstance(value, (int, float)):
            v = float(value)
            if v > 1e12:
                v = v / 1000.0
            dt = datetime.fromtimestamp(v, tz=timezone.utc)
        else:
            s = str(value)
            if s.endswith("Z"):
                s = s[:-1] + "+00:00"
            dt = datetime.fromisoformat(s)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
        now = datetime.now(timezone.utc)
        total = int((dt - now).total_seconds())
    except (ValueError, TypeError, OSError, OverflowError):
        return None
    if total <= 0:
        return "now"
    if total >= 86400:
        d = total // 86400
        h = (total % 86400) // 3600
        return f"{d}d{h}h" if h else f"{d}d"
    if total >= 3600:
        h = total // 3600
        m = (total % 3600) // 60
        return f"{h}h{m}m" if m else f"{h}h"
    m = total // 60
    if m <= 0:
        return f"{total}s"
    return f"{m}m"


def render_usage(label, pct_value, resets_at, width, gray):
    """Return a colored 'label [bar] NN% ↻reset' chunk, or None if pct missing."""
    if pct_value is None:
        return None
    try:
        pct = float(pct_value)
    except (TypeError, ValueError):
        return None
    pct = max(0.0, min(100.0, pct))
    color = gradient_color(pct)
    bar = smooth_bar(pct, width)
    rel = relative_reset(resets_at)
    suffix = f" {fg(gray)}↻{rel}{reset()}" if rel else ""
    return (
        f"{fg(gray)}{label}{reset()} "
        f"{fg(gray)}[{reset()}{fg(color)}{bar}{reset()}{fg(gray)}]{reset()} "
        f"{fg(color)}{pct:.0f}%{reset()}"
        f"{suffix}"
    )


def main() -> None:
    _ensure_utf8_stdout()
    try:
        data = json.loads(sys.stdin.read() or "{}")
    except json.JSONDecodeError:
        sys.stdout.write("(statusline: bad json)")
        return

    model = (data.get("model") or {}).get("display_name", "")
    cwd = (data.get("workspace") or {}).get("current_dir", "")
    used_pct = (data.get("context_window") or {}).get("used_percentage")

    rate_limits = data.get("rate_limits") or {}
    five_hour = rate_limits.get("five_hour") or {}
    seven_day = rate_limits.get("seven_day") or {}

    user = os.environ.get("USERNAME") or os.environ.get("USER") or "user"
    host = socket.gethostname()
    cwd_disp = shorten_cwd(cwd)

    GRAY = (0x9C, 0xA3, 0xAF)
    BLUE = (0x60, 0xA5, 0xFA)
    PURPLE = (0xC0, 0x84, 0xFC)
    ORANGE = (0xFB, 0x92, 0x3C)
    SEP = (0x4B, 0x55, 0x63)

    line1 = []
    line1.append(f"{fg(GRAY)}{user}@{host}{reset()} {fg(BLUE)}{cwd_disp}{reset()}")

    branch = find_branch(cwd)
    if branch:
        line1.append(f"{fg(PURPLE)}⎇ {branch}{reset()}")

    if model:
        line1.append(f"{fg(ORANGE)}{model}{reset()}")

    line2 = []
    ctx_chunk = render_usage("ctx", used_pct, None, 10, GRAY)
    if ctx_chunk:
        line2.append(ctx_chunk)

    fh_chunk = render_usage("5h", five_hour.get("used_percentage"), five_hour.get("resets_at"), 8, GRAY)
    if fh_chunk:
        line2.append(fh_chunk)

    sd_chunk = render_usage("7d", seven_day.get("used_percentage"), seven_day.get("resets_at"), 8, GRAY)
    if sd_chunk:
        line2.append(sd_chunk)

    sep = f" {fg(SEP)}│{reset()} "
    out = sep.join(line1)
    if line2:
        out += "\n" + sep.join(line2)
    sys.stdout.write(out)


if __name__ == "__main__":
    main()
