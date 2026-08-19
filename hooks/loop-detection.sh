#!/bin/bash
# loop-detection.sh — PostToolUse hook (Edit/Write matcher)
# Doom-loop guard: detect repeated edits to the same file and nudge a rethink.
# Claude Code hook implementation of the LangChain LoopDetectionMiddleware pattern.

set -euo pipefail

# Read JSON payload from stdin
INPUT=$(cat)

# Extract tool_name, session_id and file_path.
# Field order matters: file_path is last so `read` keeps paths containing
# spaces intact. '-' is the placeholder for an absent field, so a missing
# tool_name can never shift session_id into its slot.
read -r TOOL_NAME PAYLOAD_SID FILE_PATH <<< "$(python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    tool = data.get('tool_name', '') or '-'
    sid = data.get('session_id', '') or '-'
    fp = data.get('tool_input', {}).get('file_path', '')
    print(f'{tool} {sid} {fp}')
except Exception:
    print('- - ')
" <<< "$INPUT" 2>/dev/null || echo '- - ')"

# Ignore anything that isn't an Edit/Write tool call
[[ "$TOOL_NAME" != "Edit" && "$TOOL_NAME" != "Write" ]] && exit 0
[[ -z "$FILE_PATH" ]] && exit 0

# Determine session id. The hook payload is the only reliable source: Claude
# Code does not export CLAUDE_SESSION_ID to hook processes, so keying off the
# env var alone collapsed every concurrent session onto one machine-global
# day file and produced cross-session false positives.
SESSION_ID="$PAYLOAD_SID"
if [[ -z "$SESSION_ID" || "$SESSION_ID" == "-" ]]; then
    SESSION_ID="${CLAUDE_SESSION_ID:-}"
fi
if [[ -z "$SESSION_ID" ]]; then
    SESSION_ID="$(date +%Y%m%d)"
fi
# Keep the id filesystem-safe (it lands in a /tmp path).
SESSION_ID="${SESSION_ID//[^A-Za-z0-9_-]/_}"
TRACK_FILE="/tmp/claude-loop-detect-${SESSION_ID}.jsonl"

# Basename only (path normalization for the message)
BASENAME=$(basename "$FILE_PATH")

# Count how many times this file has already been edited this session.
# grep -c prints "0" and exits 1 when there is no match, so `|| echo 0` used to
# append a second count and make COUNT the two-line string "0\n0" — a bash
# arithmetic syntax error on the first edit of every file after the first.
COUNT=0
if [[ -f "$TRACK_FILE" ]]; then
    COUNT=$(grep -c "\"$FILE_PATH\"" "$TRACK_FILE" 2>/dev/null || true)
    COUNT=${COUNT:-0}
fi

# Record this edit
echo "{\"file\":\"$FILE_PATH\",\"ts\":\"$(date -u +%FT%TZ)\",\"tool\":\"$TOOL_NAME\"}" >> "$TRACK_FILE"
COUNT=$((COUNT + 1))

# Threshold check — build the warning text
MSG=""
if [[ $COUNT -ge 10 ]]; then
    MSG="[Loop Detection] '$BASENAME' has been edited ${COUNT} times this session — possible doom loop. Suggested: (1) check git diff for what actually changed (2) look for the root cause in a different file (3) reconsider the approach entirely."
elif [[ $COUNT -ge 5 ]]; then
    MSG="[Loop Detection] '$BASENAME' has been edited ${COUNT} times. You're repeatedly editing the same file — consider a different approach."
fi

# PostToolUse: plain stdout text is NOT delivered to Claude's context (transcript-only).
# Must use hookSpecificOutput.additionalContext (JSON on stdout) — same shape as auto-verify-fix.sh.
if [[ -n "$MSG" ]]; then
    MSG="$MSG" python3 -c "
import json, os
print(json.dumps({'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': os.environ['MSG']}}, ensure_ascii=False))
"
fi

exit 0
