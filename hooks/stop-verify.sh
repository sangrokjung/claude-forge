#!/bin/bash
# stop-verify.sh - Stop Hook
# Reminds to run verification before ending a session with code changes.
# Only triggers when actual code changes exist (git diff non-empty).
#
# Exit codes: always 0 (reminder only, never blocks)

# Skip if not in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    exit 0
fi

# Skip if no code changes in this session
DIFF_LINES=$(git diff --stat 2>/dev/null | wc -l)
STAGED_LINES=$(git diff --cached --stat 2>/dev/null | wc -l)

if [[ "$DIFF_LINES" -eq 0 ]] && [[ "$STAGED_LINES" -eq 0 ]]; then
    exit 0
fi

# Check if verification was run (marker file from /handoff-verify or test commands)
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
MARKER="/tmp/stop-verify-$SESSION_ID"

if [[ -f "$MARKER" ]]; then
    exit 0
fi

echo "[reminder] Code changes detected but no verification was run this session. Consider running /handoff-verify before ending." >&2
exit 0
