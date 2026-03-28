#!/bin/bash
# npm-scripts-guard.sh - PreToolUse Hook (Bash)
# Warns when running npm/yarn/pnpm after package.json scripts were modified.
# Prevents accidental execution of tampered scripts.
#
# Exit codes: always 0 (warn only, never blocks)
# Shows warning once per session.

INPUT=$(cat)

COMMAND=$(echo "$INPUT" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("tool_input", {}).get("command", ""))
except:
    print("")
' 2>/dev/null)

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# Check if it's an npm/yarn/pnpm run command
if ! echo "$COMMAND" | grep -qE '\b(npm\s+run|npm\s+start|npm\s+test|yarn\s|pnpm\s+run)\b'; then
    exit 0
fi

# Skip if not in a git repo
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    exit 0
fi

# Check if package.json scripts were modified (staged or unstaged)
SCRIPTS_CHANGED=$(git diff --unified=0 -- package.json 2>/dev/null | grep -c '"scripts"' || true)
SCRIPTS_STAGED=$(git diff --cached --unified=0 -- package.json 2>/dev/null | grep -c '"scripts"' || true)

if [[ "$SCRIPTS_CHANGED" -eq 0 ]] && [[ "$SCRIPTS_STAGED" -eq 0 ]]; then
    exit 0
fi

# Warn once per session (marker file)
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
MARKER_DIR="/tmp/npm-scripts-guard"
mkdir -p "$MARKER_DIR" 2>/dev/null
MARKER="$MARKER_DIR/$SESSION_ID"

if [[ -f "$MARKER" ]]; then
    exit 0
fi
touch "$MARKER"

echo "[warn] package.json scripts were modified in this session. Please verify the command before running." >&2
exit 0
