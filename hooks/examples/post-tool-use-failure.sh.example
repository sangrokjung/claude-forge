#!/usr/bin/env bash
# PostToolUseFailure hook example — claude-forge v3.0
# Event: PostToolUseFailure
# Trigger: Fires ONLY when a tool invocation fails (PostToolUse fires on both success/failure)
#
# Usage:
#   1. mkdir -p ~/.claude/hooks && cp this_file ~/.claude/hooks/post-tool-use-failure.sh
#   2. chmod +x ~/.claude/hooks/post-tool-use-failure.sh
#   3. Add to ~/.claude/settings.json hooks.PostToolUseFailure section (matcher optional)
#
# Input (stdin JSON): { "tool_name": "...", "tool_input": {...}, "error": "...", "exit_code": N }
# Output: exit 0 success, exit 2 blocking error
set -euo pipefail

LOG="${HOME}/.claude/logs/tool-failures.log"
mkdir -p "$(dirname "$LOG")"

INPUT=$(cat)
printf '%s' "$INPUT" | python3 - <<'PY' >> "$LOG" 2>/dev/null || true
import sys, json, datetime
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
ts = datetime.datetime.utcnow().isoformat() + "Z"
tool = d.get("tool_name", "unknown")
err = (d.get("error") or "")[:200].replace("\n", " ")
print(f"{ts} FAIL tool={tool} err={err}")
PY

# Escalate to Discord/stderr if three consecutive failures of the same tool occur (optional)
# tail -n 20 "$LOG" | awk '{print $3}' | sort | uniq -c | awk '$1>=3 {print "[escalate] " $2}' >&2

exit 0
