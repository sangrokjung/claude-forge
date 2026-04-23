#!/usr/bin/env bash
# StopFailure hook example — claude-forge v3.0
# Event: StopFailure
# Trigger: Fires when the session ends abnormally (crash, rate-limit, user kill)
#          — contrast with Stop which fires on clean shutdown
#
# Usage:
#   1. mkdir -p ~/.claude/hooks && cp this_file ~/.claude/hooks/stop-failure.sh
#   2. chmod +x ~/.claude/hooks/stop-failure.sh
#   3. Add to ~/.claude/settings.json hooks.StopFailure section
#
# Input (stdin JSON): { "session_id": "...", "reason": "rate_limit|crash|signal", "last_turn": "..." }
# Output: exit 0 success, exit 2 blocking error (cannot actually block — session already dying)
set -euo pipefail

DIR="${HOME}/.claude/crash-reports"
mkdir -p "$DIR"

INPUT=$(cat)
TS=$(date -u +%Y%m%dT%H%M%SZ)
OUT="${DIR}/${TS}.json"

# Persist the crash payload so the next session (--continue) can recover state
printf '%s\n' "$INPUT" > "$OUT"
printf '[stop-failure] crash report written: %s\n' "$OUT" >&2

# Optional: trip a kill-switch file so morning-sync knows to prompt for recovery
touch "${HOME}/.claude/.needs-recovery"

exit 0
