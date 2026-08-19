#!/bin/bash
# post-compact-restore.sh — PostCompact auto-restore hook (opt-in, fail-open, always exits 0).
# Think of it like this: compacting (/compact) tends to sweep away the "next task" note along with the
# clutter. This hook pulls that note back out of the locker (the pointer) exactly once (consume-once)
# right after compaction and re-injects it into the session.
#
# settings.json wires this via SessionStart (matcher: "compact").
# (The PostCompact event's hookSpecificOutput schema does not include a "PostCompact" event name, which
#  fails JSON validation — so this uses SessionStart:compact + plain-text stdout instead, the same channel
#  used by load-guard-style hooks.)
# Active automatically once this file exists. Must never exit abnormally -> always exit 0.
#
# Output contract: for SessionStart, exit 0 + stdout plain text is the standard way to inject context into
# Claude. In every other case (no pointer / already consumed / expired / bad input), emit nothing and exit 0.
set -o pipefail 2>/dev/null || true

INPUT="$(cat 2>/dev/null || true)"

# extract cwd (grep+sed, no jq dependency — same style as pre-compact-snapshot.sh)
CWD="$(printf '%s' "$INPUT" | grep -o '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/"cwd"[[:space:]]*:[[:space:]]*"//;s/"$//' | head -1)"
[ -z "$CWD" ] && exit 0

# source the library by absolute path (must match the hash the writer used)
LIB="$HOME/.claude/skills/relay/scripts/relay-lib.sh"
[ -f "$LIB" ] || exit 0
# shellcheck source=/dev/null
source "$LIB" 2>/dev/null || exit 0

HASH="$(relay_cwd_hash "$CWD" 2>/dev/null || true)"
[ -z "$HASH" ] && exit 0

POINTER="$(relay_pointer_path "$HASH" 2>/dev/null || true)"
[ -n "$POINTER" ] || exit 0
[ -f "$POINTER" ] || exit 0

CONSUMED="$(relay_consumed_path "$HASH" 2>/dev/null || true)"
[ -n "$CONSUMED" ] && [ -f "$CONSUMED" ] && exit 0

# parse the pointer + check TTL expiry + assemble the restore text (python3 is fine here)
RESULT="$(python3 - "$POINTER" <<'PY' 2>/dev/null || true
import json, sys, datetime, re

try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("SKIP"); sys.exit(0)

baton = d.get("baton") or ""
next_task = d.get("next_task") or ""
carryover = d.get("carryover") or ""
created = d.get("created") or ""
ttl = d.get("ttl_hours")
try:
    ttl = float(ttl)
except Exception:
    ttl = 12.0

def parse_dt(s):
    s = (s or "").strip()
    if not s:
        return None
    # normalize +09:00 -> +0900
    s2 = re.sub(r'([+-]\d{2}):(\d{2})$', r'\1\2', s)
    for cand in (s, s2):
        for fmt in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%S"):
            try:
                return datetime.datetime.strptime(cand, fmt)
            except Exception:
                pass
    return None

dt = parse_dt(created)
if dt is not None:
    if dt.tzinfo:
        now = datetime.datetime.now(dt.tzinfo)
    else:
        now = datetime.datetime.now()
    age_h = (now - dt).total_seconds() / 3600.0
    if age_h > ttl:
        print("EXPIRED"); sys.exit(0)

text = "[Relay restore] Next task: %s\n%s\nFull baton: %s (Read it if needed)." % (next_task, carryover, baton)
print("OK")
print(text)
PY
)"

STATUS="$(printf '%s\n' "$RESULT" | head -1)"

if [ "$STATUS" = "EXPIRED" ]; then
  rm -f "$POINTER" 2>/dev/null || true
  exit 0
fi

if [ "$STATUS" != "OK" ]; then
  exit 0
fi

RESTORE_TEXT="$(printf '%s\n' "$RESULT" | sed -n '2,$p')"
[ -z "$RESTORE_TEXT" ] && exit 0

# inject the restore context (SessionStart: plain-text stdout)
printf '%s\n' "$RESTORE_TEXT"

# record the consume-once marker
: > "$CONSUMED" 2>/dev/null || true

# clean up other expired pointers (older than 12h = 720min, excluding consumed markers)
find "$(relay_dir)" -maxdepth 1 -name '.pointer-*' ! -name '*.consumed' -mmin +720 -delete 2>/dev/null || true

exit 0
