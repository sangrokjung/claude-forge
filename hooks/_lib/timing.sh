#!/usr/bin/env bash
# hooks/_lib/timing.sh — Hook execution timing wrapper (v1.0, 2026-04-23)
#
# Purpose:
#   Wrap any hook command to measure start/end time + duration and verify
#   whether `async: true` hooks run independently in parallel or effectively
#   serial. Emits append-only JSONL that can be aggregated later.
#
# Usage (in settings.json):
#   {
#     "type": "command",
#     "command": "~/.claude/hooks/_lib/timing.sh ~/.claude/hooks/foo.sh [args...]",
#     "timeout": 10,
#     "async": true
#   }
#
# Output:
#   Appends one JSON object per line to $HOOK_TIMING_LOG
#   (default: ~/.claude/logs/hook-timing.jsonl)
#
# Env overrides:
#   HOOK_TIMING_LOG  — custom log path
#   HOOK_EVENT       — event name (SessionEnd, PreToolUse, etc.), pass via shell
#   CLAUDE_SESSION_ID — inherited from harness when available
#
# Exit behavior:
#   Preserves wrapped hook's exit code. Timing log failure never masks the hook.

set -o pipefail

HOOK_CMD="${1:?timing.sh: hook command missing}"
shift

HOOK_NAME="$(basename "$HOOK_CMD" .sh)"
LOG_FILE="${HOOK_TIMING_LOG:-$HOME/.claude/logs/hook-timing.jsonl}"
LOG_DIR="$(dirname "$LOG_FILE")"
[ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"

# ms-resolution timestamps via python3 (portable across macOS/Linux; macOS date lacks %N)
START_MS=$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s000)
START_ISO=$(python3 -c '
import time
t = time.time()
print(time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(t)) + ".{:03d}Z".format(int(t*1000) % 1000))
' 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
PID=$$
PPID_CAPTURED=$PPID

# Execute wrapped hook — preserve all args
"$HOOK_CMD" "$@"
EXIT_CODE=$?

END_MS=$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || date +%s000)
DURATION_MS=$((END_MS - START_MS))

# Append JSONL entry (non-fatal on failure)
python3 - "$HOOK_NAME" "$HOOK_CMD" "$PID" "$PPID_CAPTURED" "$START_ISO" "$START_MS" "$END_MS" "$DURATION_MS" "$EXIT_CODE" "$LOG_FILE" <<'PYEOF' 2>/dev/null || true
import json, os, sys
hook_name, hook_cmd, pid, ppid, start_iso, start_ms, end_ms, duration_ms, exit_code, log_file = sys.argv[1:11]
entry = {
    "hook": hook_name,
    "cmd": hook_cmd,
    "pid": int(pid),
    "ppid": int(ppid),
    "start_iso": start_iso,
    "start_ms": int(start_ms),
    "end_ms": int(end_ms),
    "duration_ms": int(duration_ms),
    "exit_code": int(exit_code),
    "event": os.environ.get("HOOK_EVENT", "unknown"),
    "session_id": os.environ.get("CLAUDE_SESSION_ID", "unknown"),
}
with open(log_file, "a") as f:
    f.write(json.dumps(entry, ensure_ascii=False) + "\n")
PYEOF

exit $EXIT_CODE
