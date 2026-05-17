#!/usr/bin/env bash
#
# notify.sh — send a Telegram message with an optional "↩️ Resume this session" button.
#
# Usage:
#   notify.sh --text "<markdown text>" [--uuid <session-uuid>] [--chat-id <id>]
#
# Env:
#   TELEGRAM_BOT_TOKEN   — required
#   TELEGRAM_CHAT_IDS    — comma-separated; first one is used if --chat-id not given
#
# Exit codes: 0 = sent, 2 = bad args, 3 = missing env, 4 = API error.
# Exits 0 silently if env is missing (so hooks never break the session).

set -euo pipefail

TEXT=""
UUID=""
CHAT_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --text)    TEXT="$2"; shift 2 ;;
    --uuid)    UUID="$2"; shift 2 ;;
    --chat-id) CHAT_ID="$2"; shift 2 ;;
    --silent)  exec >/dev/null 2>&1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$TEXT" ]]; then
  echo "ERROR: --text is required" >&2
  exit 2
fi

if [[ -z "${TELEGRAM_BOT_TOKEN:-}" ]]; then
  exit 0
fi

if [[ -z "$CHAT_ID" ]]; then
  IFS=',' read -r CHAT_ID _ <<<"${TELEGRAM_CHAT_IDS:-}"
fi
if [[ -z "$CHAT_ID" ]]; then
  exit 0
fi

REPLY_MARKUP=""
if [[ -n "$UUID" ]]; then
  REPLY_MARKUP=$(python3 - "$UUID" <<'PY'
import json, sys
uuid = sys.argv[1]
print(json.dumps({
    "inline_keyboard": [
        [{"text": "↩️ 이 세션 이어서 작업", "callback_data": f"cf:resume:{uuid}"}]
    ]
}))
PY
)
fi

BODY=$(python3 - "$CHAT_ID" "$TEXT" "$REPLY_MARKUP" <<'PY'
import json, sys
chat_id, text, markup = sys.argv[1], sys.argv[2], sys.argv[3]
payload = {
    "chat_id": chat_id,
    "text": text,
    "parse_mode": "Markdown",
    "disable_web_page_preview": True,
}
if markup:
    payload["reply_markup"] = json.loads(markup)
print(json.dumps(payload, ensure_ascii=False))
PY
)

RESPONSE_FILE=$(mktemp)
trap 'rm -f "$RESPONSE_FILE"' EXIT
HTTP_CODE=$(curl -sS -o "$RESPONSE_FILE" -w '%{http_code}' \
  -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  --data-binary "$BODY" || echo "000")

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "telegram notify failed: HTTP $HTTP_CODE" >&2
  head -c 500 "$RESPONSE_FILE" >&2
  exit 4
fi
