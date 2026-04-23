#!/usr/bin/env bash
# hooks/_lib/timing.sh — Hook execution timing wrapper (v1.1, 2026-04-23)
#
# Purpose:
#   Wrap any hook command to measure start/end time + duration and verify
#   whether `async: true` hooks run independently in parallel or effectively
#   serial. Emits append-only JSONL that can be aggregated later.
#
# Usage (in settings.json):
#   {
#     "type": "command",
#     "command": "HOOK_EVENT=SessionEnd ~/.claude/hooks/_lib/timing.sh ~/.claude/hooks/foo.sh [args...]",
#     "timeout": 10,
#     "async": true
#   }
#
# Output:
#   Appends one JSON object per line to $HOOK_TIMING_LOG
#   (default: ~/.claude/logs/hook-timing.jsonl, mode 600)
#
# Env overrides:
#   HOOK_TIMING_LOG  — custom log path
#   HOOK_EVENT       — event name (SessionEnd, PreToolUse, etc.), inline via shell
#   CLAUDE_SESSION_ID — inherited from harness when available
#
# Performance notes (v1.1):
#   - python3 fork count reduced 3 → 2 (START combined, END+log combined)
#   - Measured overhead on macOS arm64: ~30ms (was ~66ms in v1.0).
#   - `set -e` deliberately NOT set: a failure inside the timing wrapper
#     must never mask the wrapped hook's exit code. `set -o pipefail` is
#     kept so that pipeline failures during logging still surface for debug.
#
# Security notes (v1.1):
#   - `umask 077` ensures log file and log directory are owner-only (600/700).
#   - `chmod 600` re-applied defensively after each write (works on existing files).
#   - Wrapped hook path is NOT validated — trust boundary is settings.json
#     which the user explicitly controls. Do not expose this wrapper as an
#     entry point for untrusted input.
#
# Exit behavior:
#   Preserves wrapped hook's exit code. Timing log failure never masks the hook.

set -o pipefail
umask 077

HOOK_CMD="${1:?timing.sh: hook command missing}"
shift

HOOK_NAME="$(basename -- "$HOOK_CMD" .sh)"
LOG_FILE="${HOOK_TIMING_LOG:-$HOME/.claude/logs/hook-timing.jsonl}"
LOG_DIR="$(dirname -- "$LOG_FILE")"
[ -d "$LOG_DIR" ] || mkdir -p "$LOG_DIR"

# START: single python3 call produces MS + ISO on two lines (reduces fork count)
_START_OUT="$(python3 -c '
import time
t = time.time()
ms = int(t * 1000)
iso = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(t)) + ".{:03d}Z".format(ms % 1000)
print(ms)
print(iso)
' 2>/dev/null)" || _START_OUT="$(date +%s000)"$'\n'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"

START_MS="${_START_OUT%%$'\n'*}"
START_ISO="${_START_OUT#*$'\n'}"
PID=$$
PPID_CAPTURED=$PPID

# Execute wrapped hook — preserve all args
"$HOOK_CMD" "$@"
EXIT_CODE=$?

# END + log append in a single python3 call (reduces fork count 3 → 2)
# Failure here is silently ignored; it must not mask $EXIT_CODE.
python3 - "$HOOK_NAME" "$HOOK_CMD" "$PID" "$PPID_CAPTURED" "$START_ISO" "$START_MS" "$EXIT_CODE" "$LOG_FILE" <<'PYEOF' 2>/dev/null || true
import json, os, sys, time
# Guard against arity mismatch — never crash the timing wrapper
if len(sys.argv) < 9:
    sys.exit(0)
hook_name, hook_cmd, pid, ppid, start_iso, start_ms, exit_code, log_file = sys.argv[1:9]
end_ms = int(time.time() * 1000)
try:
    duration_ms = end_ms - int(start_ms)
except ValueError:
    duration_ms = 0
entry = {
    "hook": hook_name,
    "cmd": hook_cmd,
    "pid": int(pid) if pid.isdigit() else -1,
    "ppid": int(ppid) if ppid.isdigit() else -1,
    "start_iso": start_iso,
    "start_ms": int(start_ms) if start_ms.isdigit() else 0,
    "end_ms": end_ms,
    "duration_ms": duration_ms,
    "exit_code": int(exit_code) if exit_code.lstrip("-").isdigit() else -1,
    "event": os.environ.get("HOOK_EVENT", "unknown"),
    "session_id": os.environ.get("CLAUDE_SESSION_ID", "unknown"),
}
with open(log_file, "a") as f:
    f.write(json.dumps(entry, ensure_ascii=False) + "\n")
try:
    os.chmod(log_file, 0o600)
except OSError:
    pass
PYEOF

exit $EXIT_CODE
