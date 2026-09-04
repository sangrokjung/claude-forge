#!/usr/bin/env bash
#
# telegram-resume-notify.sh — Stop hook that sends a Telegram message
# with a one-tap "↩️ Resume this session" button when a Claude Code
# turn ends cleanly.
#
# Wire via hooks.json:
#   {
#     "Stop": [
#       { "hooks": [
#           { "type": "command",
#             "command": "$CLAUDE_FORGE_HOME/hooks/telegram-resume-notify.sh",
#             "timeout": 10 }
#       ]}
#     ]
#   }
#
# Env (required):
#   TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_IDS  — silent no-op if unset.
#
# Env (optional):
#   TELEGRAM_RESUME_NOTIFY_DIR  — folder containing notify.sh
#                                 (default: $HOME/.claude-forge/telegram-resume)
#   TELEGRAM_RESUME_NOTIFY_MIN_TURNS — skip notification if turn_count < N (default: 2)
#
# Always exits 0 — never blocks the session.

set -u

INPUT=$(cat || true)

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_CHAT_IDS:-}" ]]; then
  exit 0
fi

NOTIFY_DIR="${TELEGRAM_RESUME_NOTIFY_DIR:-$HOME/.claude-forge/telegram-resume}"
NOTIFY_SH="${NOTIFY_DIR}/notify.sh"

if [[ ! -x "$NOTIFY_SH" ]]; then
  exit 0
fi

MIN_TURNS="${TELEGRAM_RESUME_NOTIFY_MIN_TURNS:-2}"

PARSED="$(TELEGRAM_STOP_INPUT_JSON="$INPUT" python3 -c '
import sys, json, os
try:
    d = json.loads(os.environ.get("TELEGRAM_STOP_INPUT_JSON", ""))
except Exception:
    sys.exit(0)
# Tab-separated to survive spaces in any field (paths, branches, etc.)
print("\t".join([
    d.get("session_id", ""),
    d.get("cwd", ""),
    d.get("git_branch", ""),
    d.get("transcript_path", ""),
]))
' 2>/dev/null)"
IFS=$'\t' read -r SESSION_ID CWD GIT_BRANCH TRANSCRIPT_PATH <<<"$PARSED"

if [[ -z "${SESSION_ID:-}" ]]; then
  exit 0
fi

PROJECT="$(basename "${CWD:-unknown}")"
BRANCH_SHORT=""
if [[ -n "${GIT_BRANCH:-}" ]]; then
  BRANCH_SHORT="${GIT_BRANCH##*/}"
fi

LAST_MESSAGE=""
TURN_COUNT=0
if [[ -n "${TRANSCRIPT_PATH:-}" && -f "$TRANSCRIPT_PATH" ]]; then
  read -r TURN_COUNT LAST_MESSAGE <<<"$(
    python3 - "$TRANSCRIPT_PATH" <<'PY'
import json, sys, collections
path = sys.argv[1]
turn_count = 0
last_user_text = ""
buf = collections.deque(maxlen=200)
try:
    with open(path, "r", encoding="utf-8", errors="replace") as fp:
        for line in fp:
            turn_count += 1
            buf.append(line)
except OSError:
    pass

for line in reversed(buf):
    try:
        d = json.loads(line)
    except Exception:
        continue
    if d.get("type") == "user":
        msg = d.get("message", {})
        content = msg.get("content", "") if isinstance(msg, dict) else ""
        if isinstance(content, list):
            parts = [c.get("text", "") for c in content if isinstance(c, dict) and c.get("type") == "text"]
            content = " ".join(p for p in parts if p)
        if isinstance(content, str) and content.strip():
            last_user_text = " ".join(content.split())[:100]
            break
print(turn_count, last_user_text)
PY
  )"
fi

if (( TURN_COUNT < MIN_TURNS )); then
  exit 0
fi

HANDOFF_SH="${TELEGRAM_HANDOFF_HOOK:-$(dirname "$0")/handoff-telegram.sh}"
if [[ -x "$HANDOFF_SH" ]]; then
  "$HANDOFF_SH" --cleanup 2>/dev/null || true
fi

TEXT="✅ *${PROJECT}* 세션 종료"
if [[ -n "$BRANCH_SHORT" ]]; then
  TEXT="${TEXT} · \`${BRANCH_SHORT}\`"
fi
if [[ -n "$LAST_MESSAGE" ]]; then
  ESCAPED_MSG="${LAST_MESSAGE//\\/\\\\}"
  ESCAPED_MSG="${ESCAPED_MSG//\`/\\\`}"
  ESCAPED_MSG="${ESCAPED_MSG//\*/\\*}"
  ESCAPED_MSG="${ESCAPED_MSG//_/\\_}"
  TEXT+=$'\n'"_\"${ESCAPED_MSG}\"_"
fi
TEXT+=$'\n'"${TURN_COUNT}턴 · \`${SESSION_ID:0:8}\`"

"$NOTIFY_SH" --text "$TEXT" --uuid "$SESSION_ID" --silent || true
exit 0
