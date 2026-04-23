#!/usr/bin/env bash
# SubagentStop hook example — claude-forge v3.0
# Event: SubagentStop
# Trigger: Fires when a subagent finishes (success or failure)
#
# Usage:
#   1. mkdir -p ~/.claude/hooks && cp this_file ~/.claude/hooks/subagent-stop.sh
#   2. chmod +x ~/.claude/hooks/subagent-stop.sh
#   3. Add to ~/.claude/settings.json hooks.SubagentStop section
#
# Input (stdin JSON): { "subagent_name": "...", "exit_status": "success|failure", "session_id": "..." }
# Output: exit 0 success, exit 2 blocking error
set -euo pipefail

LOG="${HOME}/.claude/logs/subagent.log"
mkdir -p "$(dirname "$LOG")"

INPUT=$(cat)
NAME=$(printf '%s' "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('subagent_name','unknown'))" 2>/dev/null || echo "unknown")
STATUS=$(printf '%s' "$INPUT" | python3 -c "import sys,json;print(json.load(sys.stdin).get('exit_status','unknown'))" 2>/dev/null || echo "unknown")

# Compute duration if SubagentStart dropped a start marker
START_FILE="${HOME}/.claude/logs/subagent-${NAME}.start"
DURATION="n/a"
if [ -f "$START_FILE" ]; then
  START=$(cat "$START_FILE")
  DURATION="$(( $(date +%s) - START ))s"
  rm -f "$START_FILE"
fi

printf '%s STOP  %s status=%s duration=%s\n' "$(date -u +%FT%TZ)" "$NAME" "$STATUS" "$DURATION" >> "$LOG"

exit 0
