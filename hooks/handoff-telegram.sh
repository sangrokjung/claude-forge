#!/usr/bin/env bash
#
# handoff-telegram.sh — UserPromptSubmit hook.
#
# Mac-side triggers (all block the prompt from reaching Claude):
#   /tg | /handoff-tg | >>tg          → START bridge
#   /tg-end | /end-tg | /handoff-end  → STOP bridge (clean PC-return)
#
# Cleanup mode (called by Stop hook on session exit):
#   handoff-telegram.sh --cleanup
#
# Wire via hooks.json — install.sh registers automatically. See
# hooks/examples/telegram-resume-notify.hooks.json.example for manual setup.

set -u

CLEANUP=0
if [[ "${1:-}" == "--cleanup" ]]; then
  CLEANUP=1
fi

STATE_DIR="${TELEGRAM_BRIDGE_STATE_DIR:-$HOME/.claude-forge/telegram-resume/state}"
STATE_FILE="$STATE_DIR/bridge.json"
NOTIFY_DIR="${TELEGRAM_RESUME_NOTIFY_DIR:-$HOME/.claude-forge/telegram-resume}"
NOTIFY_SH="$NOTIFY_DIR/notify.sh"

mkdir -p "$STATE_DIR" 2>/dev/null || true

if (( CLEANUP )); then
  if [[ -f "$STATE_FILE" ]]; then
    rm -f "$STATE_FILE"
    if [[ -x "$NOTIFY_SH" && -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
      "$NOTIFY_SH" --text "🛑 _세션 종료 — bridge 자동 해제_" --silent 2>/dev/null || true
    fi
  fi
  exit 0
fi

INPUT=$(cat || true)
if [[ -z "$INPUT" ]]; then
  exit 0
fi

# --- TMUX target resolution (must happen in shell, not subshell) -----
TMUX_TARGET=""
if [[ -n "${TMUX_PANE:-}" ]]; then
  TMUX_TARGET="$(tmux display -p -t "$TMUX_PANE" '#S:#I.#P' 2>/dev/null || true)"
fi
if [[ -z "$TMUX_TARGET" && -n "${TMUX:-}" ]]; then
  TMUX_TARGET="$(tmux display -p '#S:#I.#P' 2>/dev/null || true)"
fi

# --- Single Python call: parses input, resolves jsonl, writes state ---
# Returns one of:
#   OK <tab> <session_id_short> <tab> <project_name>
#   SKIP <reason>            (non-trigger prompt — exit 0)
#   ERR <reason>             (trigger but config bad — exit 2 with message)
#   ALREADY <reason>         (already bridged — exit 2 with note)

RESULT="$(TELEGRAM_BRIDGE_STATE_FILE="$STATE_FILE" \
    TELEGRAM_BRIDGE_TMUX_TARGET="$TMUX_TARGET" \
    TELEGRAM_BRIDGE_INPUT_JSON="$INPUT" \
    python3 - <<'PY'
import sys, json, os, pathlib, datetime, re

PROMPT_START_RE = re.compile(r"^(/tg|/handoff-tg|>>tg)(\s|$)")
PROMPT_END_RE   = re.compile(r"^(/tg-end|/end-tg|/handoff-end)(\s|$)")

def emit(tag: str, *fields: str) -> None:
    print("\t".join([tag, *fields]))
    sys.exit(0)

try:
    payload = json.loads(os.environ.get("TELEGRAM_BRIDGE_INPUT_JSON", ""))
except Exception as exc:
    emit("SKIP", f"bad-json:{exc}")

prompt = payload.get("prompt") or ""

# Mac-side END branch — clear state, notify Telegram, block the prompt.
if PROMPT_END_RE.match(prompt):
    state_file = pathlib.Path(os.environ["TELEGRAM_BRIDGE_STATE_FILE"])
    if state_file.exists():
        try:
            existing = json.loads(state_file.read_text(encoding="utf-8"))
            short_uuid = (existing.get("session_uuid") or "")[:8]
        except (OSError, json.JSONDecodeError):
            short_uuid = ""
        try:
            state_file.unlink()
        except OSError:
            pass
        emit("ENDED", short_uuid or "(unknown)")
    emit("ENDED-NOOP", "활성 bridge 없음")

if not PROMPT_START_RE.match(prompt):
    emit("SKIP", "no-trigger")

bot_token = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
chat_ids = os.environ.get("TELEGRAM_CHAT_IDS", "").strip()
if not bot_token or not chat_ids:
    emit("ERR", "TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_IDS 미설정")

session_id = payload.get("session_id") or ""
if not session_id:
    emit("ERR", "session_id 없음 — bridge 시작 불가")

cwd = payload.get("cwd") or os.environ.get("PWD") or ""
git_branch = payload.get("git_branch") or ""

tmux_target = os.environ.get("TELEGRAM_BRIDGE_TMUX_TARGET", "").strip()
if not tmux_target:
    emit("ERR", "tmux 외부에서 실행 중 — bridge는 tmux 필요. 'tmux new-session claude' 안에서 다시 시도하세요")

# Resolve jsonl path — prefer explicit project slug, fall back to find
slug = cwd.replace("/", "-")
projects_root = pathlib.Path.home() / ".claude" / "projects"
jsonl_path = projects_root / slug / f"{session_id}.jsonl"
if not jsonl_path.exists():
    for candidate in projects_root.glob(f"*/{session_id}.jsonl"):
        jsonl_path = candidate
        break

# State file path
state_file = pathlib.Path(os.environ["TELEGRAM_BRIDGE_STATE_FILE"])

# Detect re-trigger: same session already bridged?
if state_file.exists():
    try:
        existing = json.loads(state_file.read_text(encoding="utf-8"))
        if existing.get("active") and existing.get("session_uuid") == session_id:
            emit("ALREADY", f"이미 bridge 활성 (세션 {session_id[:8]})")
    except (OSError, json.JSONDecodeError):
        pass  # corrupted state — overwrite

chat_id = chat_ids.split(",")[0].strip()
project_name = pathlib.Path(cwd).name if cwd else session_id[:8]
branch_short = git_branch.rsplit("/", 1)[-1]
size_at_start = jsonl_path.stat().st_size if jsonl_path.exists() else 0
now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")

state_payload = {
    "active": True,
    "session_uuid": session_id,
    "jsonl_path": str(jsonl_path),
    "tmux_target": tmux_target,
    "chat_id": chat_id,
    "project_name": project_name,
    "git_branch": branch_short,
    "started_at": now_iso,
    "last_activity_at": now_iso,
    "jsonl_size_at_start": size_at_start,
}

state_file.parent.mkdir(parents=True, exist_ok=True)
tmp = state_file.with_suffix(".tmp")
tmp.write_text(json.dumps(state_payload, indent=2, ensure_ascii=False), encoding="utf-8")
tmp.replace(state_file)

emit("OK", session_id[:8], project_name, branch_short, tmux_target)
PY
)"

# --- Dispatch on result ----------------------------------------------------
TAG="${RESULT%%$'\t'*}"
REST="${RESULT#*$'\t'}"

case "$TAG" in
  SKIP)
    exit 0
    ;;
  ERR)
    echo "⚠️  /tg 트리거 실패: $REST" >&2
    if [[ "$REST" == *"미설정"* ]]; then
      echo "   ~/.claude-forge/telegram-resume/.env 를 먼저 설정하세요." >&2
    fi
    exit 2
    ;;
  ALREADY)
    cat >&2 <<EOF
🔌 $REST
   이미 활성 — Telegram에서 계속 작업하거나, '/tg-end' 후 다시 /tg 하세요.
EOF
    exit 2
    ;;
  ENDED)
    if [[ -x "$NOTIFY_SH" && -n "${TELEGRAM_BOT_TOKEN:-}" ]]; then
      "$NOTIFY_SH" \
        --text "🛑 _Mac 키보드로 복귀 — bridge 종료됨._ (\`${REST}\`)" \
        --silent 2>/dev/null || true
    fi
    cat >&2 <<EOF
🛑 Telegram bridge 종료됨
   세션: ${REST}
   이제 Mac에서 평소처럼 입력하세요. 폰 동기화 끊김.
EOF
    exit 2
    ;;
  ENDED-NOOP)
    echo "ℹ️  활성 bridge 없음 — 종료할 것 없음" >&2
    exit 2
    ;;
  OK)
    # Parse OK details: <short> <project> <branch> <tmux>
    IFS=$'\t' read -r OK_SHORT OK_PROJECT OK_BRANCH OK_TMUX <<<"$REST"

    if [[ -x "$NOTIFY_SH" ]]; then
      TEXT="🔌 *Bridge 모드 시작*"$'\n'
      TEXT+="세션: \`${OK_SHORT}\` · ${OK_PROJECT} · \`${OK_BRANCH:-HEAD}\`"$'\n'
      TEXT+="tmux: \`${OK_TMUX}\`"$'\n\n'
      TEXT+="_입력한 메시지가 Mac tmux에 자동 주입되고,_"$'\n'
      TEXT+="_Claude 응답이 실시간으로 여기에 표시됩니다._"$'\n\n'
      TEXT+="종료: Telegram에서 \`/end\` 또는 Mac에서 \`/tg-end\`"
      "$NOTIFY_SH" --text "$TEXT" --silent 2>/dev/null || true
    fi

    cat >&2 <<EOF
🔌 Telegram bridge 활성화됨
   세션: ${OK_SHORT} · ${OK_PROJECT} · ${OK_BRANCH:-HEAD}
   tmux: ${OK_TMUX}
   상태: ${STATE_FILE}

📱 Telegram 앱을 열어 메시지를 입력하세요.
   종료: Telegram에서 '/end' 또는 Mac에서 '/tg-end'
EOF
    exit 2
    ;;
  *)
    echo "⚠️  handoff 훅 내부 오류: $RESULT" >&2
    exit 2
    ;;
esac
