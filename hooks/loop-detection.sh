#!/bin/bash
# loop-detection.sh — PostToolUse hook (Edit/Write matcher)
# Doom-loop guard: detect repeated edits to the same file and nudge a rethink.
# Claude Code hook implementation of the LangChain LoopDetectionMiddleware pattern.

set -euo pipefail

# Read JSON payload from stdin
INPUT=$(cat)

# Extract tool_name and file_path
read -r TOOL_NAME FILE_PATH <<< "$(python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    tool = data.get('tool_name', '')
    fp = data.get('tool_input', {}).get('file_path', '')
    print(f'{tool} {fp}')
except:
    print(' ')
" <<< "$INPUT" 2>/dev/null || echo ' ')"

# Ignore anything that isn't an Edit/Write tool call
[[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]] && exit 0
[[ -z "$FILE_PATH" ]] && exit 0

# Determine session id
SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%Y%m%d)}"
TRACK_FILE="/tmp/claude-loop-detect-${SESSION_ID}.jsonl"

# Basename only (path normalization for the message)
BASENAME=$(basename "$FILE_PATH")

# Count how many times this file has already been edited this session
COUNT=0
if [[ -f "$TRACK_FILE" ]]; then
    COUNT=$(grep -c "\"$FILE_PATH\"" "$TRACK_FILE" 2>/dev/null || echo "0")
fi

# Record this edit
echo "{\"file\":\"$FILE_PATH\",\"ts\":\"$(date -u +%FT%TZ)\",\"tool\":\"$TOOL_NAME\"}" >> "$TRACK_FILE"
COUNT=$((COUNT + 1))

# Threshold check
if [[ $COUNT -ge 10 ]]; then
    echo "[Loop Detection] '$BASENAME' has been edited ${COUNT} times this session — possible doom loop. Suggested: (1) check git diff for what actually changed (2) look for the root cause in a different file (3) reconsider the approach entirely."
elif [[ $COUNT -ge 5 ]]; then
    echo "[Loop Detection] '$BASENAME' has been edited ${COUNT} times. You're repeatedly editing the same file — consider a different approach."
fi

exit 0
