"""Telegram resume bot — long-polling, dependency-light.

Run with:
    python3 bot.py

Requires:
    - TELEGRAM_BOT_TOKEN   — from @BotFather
    - TELEGRAM_CHAT_IDS    — comma-separated allowlist of chat IDs
    - CLAUDE_RESUME_EXECUTOR — path to executor.sh (default: ./executor.sh)

Implements:
    - /start, /resume, /sessions, /help commands
    - cf:resume:<uuid> | latest  — show confirmation screen
    - cf:exec:r:<short>           — invoke executor in resume mode
    - cf:exec:f:<short>           — invoke executor in fork mode
    - cf:exec:rc:<short>          — invoke executor in remote-control mode
    - cf:list:page=N | refresh    — pagination
    - cf:cancel                   — dismiss confirmation
    - cf:settings                 — show settings dialog
"""

from __future__ import annotations

import json
import logging
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

import requests

from bridge import BridgeManager
from keyboard import (
    build_confirm_keyboard,
    build_main_keyboard,
    build_post_exec_keyboard,
    render_confirm_text,
    render_session_list_text,
)
from sessions import (
    CLAUDE_PROJECTS_DIR,
    SessionMeta,
    find_session,
    list_sessions,
)


BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "").strip()
ALLOWED_CHATS = {
    s.strip()
    for s in os.environ.get("TELEGRAM_CHAT_IDS", "").split(",")
    if s.strip()
}
EXECUTOR_PATH = Path(
    os.environ.get(
        "CLAUDE_RESUME_EXECUTOR",
        str(Path(__file__).parent / "executor.sh"),
    )
).expanduser()
POLL_TIMEOUT = int(os.environ.get("TELEGRAM_POLL_TIMEOUT", "25"))
SESSION_LIST_LIMIT = int(os.environ.get("TELEGRAM_LIST_LIMIT", "20"))


API_BASE = f"https://api.telegram.org/bot{BOT_TOKEN}" if BOT_TOKEN else ""
HELP_TEXT = (
    "🤖 *Claude Code 세션 이어서 작업 봇*\n\n"
    "*명령어*\n"
    "/sessions — 최근 세션 목록\n"
    "/resume — 가장 최근 세션 즉시 이어가기\n"
    "/bridge — 현재 bridge 상태\n"
    "/end — bridge 모드 종료\n"
    "/health — 진단 정보\n"
    "/help — 이 도움말\n\n"
    "*Bridge 모드 (Mac에서 `/tg` 트리거)*\n"
    "활성 시: 입력하는 텍스트가 Mac tmux에 자동 주입되고,\n"
    "Claude 응답이 실시간으로 여기로 전달됩니다.\n\n"
    "*Resume 버튼*\n"
    "⚡ 가장 최근 이어서 — 최근 1개를 바로 실행\n"
    "▶ N. 프로젝트 — 그 세션의 확인 화면\n"
    "🍴 fork — 같은 시작점에서 새 세션\n"
    "🖥️ Remote Control — RC 모드로 실행"
)

_running = True
log = logging.getLogger("telegram-resume-bot")
_bridge: BridgeManager | None = None


def _setup_logging() -> None:
    level = os.environ.get("TELEGRAM_LOG_LEVEL", "INFO").upper()
    logging.basicConfig(
        level=getattr(logging, level, logging.INFO),
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )


def _check_config() -> None:
    if not BOT_TOKEN:
        sys.exit("ERROR: TELEGRAM_BOT_TOKEN is not set.")
    if not ALLOWED_CHATS:
        sys.exit("ERROR: TELEGRAM_CHAT_IDS is empty — allowlist must have at least one ID.")
    if not EXECUTOR_PATH.exists():
        log.warning("Executor missing at %s — resume actions will fail.", EXECUTOR_PATH)


def _api(method: str, **payload: Any) -> dict:
    """Call Telegram Bot API.  Returns the parsed JSON body even on 4xx so
    callers can inspect `ok` / `description` and decide whether to retry."""
    url = f"{API_BASE}/{method}"
    try:
        resp = requests.post(url, json=payload, timeout=POLL_TIMEOUT + 5)
    except requests.RequestException as exc:
        log.warning("API call %s failed: %s", method, exc)
        return {"ok": False, "description": f"transport: {exc}"}
    try:
        body = resp.json()
    except ValueError:
        body = {"ok": False, "description": f"non-json HTTP {resp.status_code}"}
    if resp.status_code != 200 and resp.status_code != 400:
        log.warning("API %s returned %s: %s", method, resp.status_code, resp.text[:200])
    return body if isinstance(body, dict) else {"ok": False, "description": str(body)}


def send_message(chat_id: str, text: str, keyboard: dict | None = None) -> dict:
    """Send message with parse_mode=Markdown.  On parse failure, retry as
    plain text so the user always sees *something* instead of nothing."""
    payload: dict = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "Markdown",
        "disable_web_page_preview": True,
    }
    if keyboard:
        payload["reply_markup"] = keyboard
    result = _api("sendMessage", **payload)
    if result.get("ok"):
        return result

    desc = str(result.get("description", "")).lower()
    if "can't parse entities" in desc or "parse" in desc:
        log.warning("Markdown parse failed (%s) — retrying as plain text", desc[:120])
        payload.pop("parse_mode", None)
        retry = _api("sendMessage", **payload)
        if retry.get("ok"):
            return retry
        log.warning("Plain-text retry also failed: %s", retry.get("description"))
    else:
        log.warning("sendMessage failed: %s", result.get("description"))
    return result


def edit_message(chat_id: str, message_id: int, text: str, keyboard: dict | None = None) -> dict:
    payload: dict = {
        "chat_id": chat_id,
        "message_id": message_id,
        "text": text,
        "parse_mode": "Markdown",
        "disable_web_page_preview": True,
    }
    if keyboard:
        payload["reply_markup"] = keyboard
    result = _api("editMessageText", **payload)
    if result.get("ok"):
        return result
    desc = str(result.get("description", "")).lower()
    if "can't parse entities" in desc or "parse" in desc:
        log.warning("editMessageText Markdown parse failed — retrying plain")
        payload.pop("parse_mode", None)
        return _api("editMessageText", **payload)
    return result


def answer_callback(callback_id: str, text: str = "", show_alert: bool = False) -> dict:
    return _api(
        "answerCallbackQuery",
        callback_query_id=callback_id,
        text=text,
        show_alert=show_alert,
    )


def _is_authorized(chat_id: Any) -> bool:
    return str(chat_id) in ALLOWED_CHATS


def _short_to_full_uuid(short: str) -> str | None:
    """Resolve 8-char prefix to full UUID using session index."""
    if len(short) >= 36:
        return short
    for s in list_sessions(limit=200):
        if s.uuid.startswith(short):
            return s.uuid
    return None


def _run_executor(mode: str, uuid: str) -> tuple[bool, str]:
    """Invoke executor.sh — returns (ok, message)."""
    if not EXECUTOR_PATH.exists():
        return False, f"executor not found: {EXECUTOR_PATH}"
    try:
        result = subprocess.run(
            [str(EXECUTOR_PATH), mode, uuid],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except subprocess.TimeoutExpired:
        return False, "executor timed out (30s)"
    except OSError as exc:
        return False, f"executor failed: {exc}"
    ok = result.returncode == 0
    msg = (result.stdout or "").strip() or (result.stderr or "").strip() or "(no output)"
    return ok, msg


def handle_command(chat_id: str, command: str, args: str) -> None:
    cmd = command.lower().split("@")[0]

    if cmd in ("/start", "/help"):
        send_message(chat_id, HELP_TEXT)
        return

    if cmd in ("/sessions", "/list"):
        sessions = list_sessions(limit=SESSION_LIST_LIMIT)
        send_message(
            chat_id,
            render_session_list_text(sessions, page=0),
            build_main_keyboard(sessions, page=0),
        )
        return

    if cmd == "/resume":
        sessions = list_sessions(limit=1)
        if not sessions:
            send_message(chat_id, "_최근 세션을 찾지 못했습니다._")
            return
        latest = sessions[0]
        send_message(
            chat_id,
            render_confirm_text(latest, mode="resume"),
            build_confirm_keyboard(latest.uuid),
        )
        return

    if cmd in ("/bridge", "/status"):
        if _bridge is None:
            send_message(chat_id, "_Bridge manager 미초기화_")
        else:
            send_message(chat_id, _bridge.status_text())
        return

    if cmd in ("/health", "/diag"):
        send_message(chat_id, _build_health_report())
        return

    if cmd in ("/end", "/stop", "/handoff-end"):
        if _bridge is None or not _bridge.is_active():
            send_message(chat_id, "_활성 bridge 없음._")
            return
        prev = _bridge.stop(reason=f"telegram:{cmd}")
        send_message(
            chat_id,
            f"🛑 Bridge 종료\n세션: `{prev.session_uuid[:8] if prev else '?'}`\n"
            "Mac 터미널에서 계속 작업하세요.",
        )
        return

    send_message(chat_id, f"알 수 없는 명령: `{command}`\n/help 를 확인하세요.")


def handle_callback(callback: dict) -> None:
    callback_id = callback["id"]
    data = callback.get("data", "")
    message = callback.get("message", {}) or {}
    chat_id = str(message.get("chat", {}).get("id", ""))
    message_id = message.get("message_id")

    if not _is_authorized(chat_id):
        answer_callback(callback_id, "권한 없음", show_alert=True)
        return

    log.info("callback chat=%s data=%s", chat_id, data)

    if data == "cf:cancel":
        answer_callback(callback_id, "취소됨")
        if message_id:
            edit_message(chat_id, message_id, "❌ _취소되었습니다._")
        return

    if data == "cf:settings":
        answer_callback(callback_id)
        text = (
            "*⚙️ 설정*\n\n"
            f"Allowed chats: `{len(ALLOWED_CHATS)}` IDs\n"
            f"Projects dir: `{CLAUDE_PROJECTS_DIR}`\n"
            f"Executor: `{EXECUTOR_PATH}`\n"
            f"List limit: `{SESSION_LIST_LIMIT}`"
        )
        if message_id:
            edit_message(chat_id, message_id, text, build_post_exec_keyboard())
        return

    if data.startswith("cf:list:"):
        sub = data[len("cf:list:"):]
        page = 0
        if sub.startswith("page="):
            try:
                page = int(sub.split("=", 1)[1])
            except ValueError:
                page = 0
        sessions = list_sessions(limit=SESSION_LIST_LIMIT)
        answer_callback(callback_id, "새로고침" if sub == "refresh" else "")
        if message_id:
            edit_message(
                chat_id,
                message_id,
                render_session_list_text(sessions, page=page),
                build_main_keyboard(sessions, page=page),
            )
        return

    if data == "cf:resume:latest":
        sessions = list_sessions(limit=1)
        if not sessions:
            answer_callback(callback_id, "세션 없음", show_alert=True)
            return
        latest = sessions[0]
        answer_callback(callback_id, "확인 화면")
        if message_id:
            edit_message(
                chat_id,
                message_id,
                render_confirm_text(latest, mode="resume"),
                build_confirm_keyboard(latest.uuid),
            )
        return

    if data.startswith("cf:resume:"):
        uuid = data[len("cf:resume:"):]
        meta = find_session(uuid)
        if not meta:
            answer_callback(callback_id, "세션을 찾지 못했습니다.", show_alert=True)
            return
        answer_callback(callback_id)
        if message_id:
            edit_message(
                chat_id,
                message_id,
                render_confirm_text(meta, mode="resume"),
                build_confirm_keyboard(meta.uuid),
            )
        return

    if data.startswith("cf:exec:"):
        parts = data.split(":")
        if len(parts) != 4:
            answer_callback(callback_id, "잘못된 콜백", show_alert=True)
            return
        mode_code, short = parts[2], parts[3]
        mode_map = {"r": "resume", "f": "fork", "rc": "rc"}
        mode = mode_map.get(mode_code)
        if not mode:
            answer_callback(callback_id, f"알 수 없는 모드: {mode_code}", show_alert=True)
            return
        full_uuid = _short_to_full_uuid(short)
        if not full_uuid:
            answer_callback(callback_id, "UUID 미해결", show_alert=True)
            return

        answer_callback(callback_id, "실행 중…")
        ok, msg = _run_executor(mode, full_uuid)
        icon = "✅" if ok else "⚠️"
        body = (
            f"{icon} *{mode.upper()}* 실행 결과\n\n"
            f"세션: `{full_uuid[:8]}`\n"
            f"```\n{msg[:1500]}\n```"
        )
        if message_id:
            edit_message(chat_id, message_id, body, build_post_exec_keyboard())
        return

    answer_callback(callback_id, "알 수 없는 액션")


def handle_update(update: dict) -> None:
    if "callback_query" in update:
        cb = update["callback_query"]
        from_chat = str(cb.get("message", {}).get("chat", {}).get("id", ""))
        if not _is_authorized(from_chat):
            log.warning("Rejecting callback from unauthorized chat: %s", from_chat)
            answer_callback(cb["id"], "권한 없음", show_alert=True)
            return
        handle_callback(cb)
        return

    msg = update.get("message")
    if not msg:
        return

    chat_id = str(msg.get("chat", {}).get("id", ""))
    if not _is_authorized(chat_id):
        log.warning("Rejecting message from unauthorized chat: %s", chat_id)
        send_message(chat_id, "🚫 _권한 없음_  (chat_id 미등록)")
        return

    text = (msg.get("text") or "").strip()
    if not text:
        return

    if text.startswith("/"):
        head, _, rest = text.partition(" ")
        handle_command(chat_id, head, rest)
        return

    if _bridge is not None and _bridge.is_active():
        ok, result = _bridge.inject(text)
        if ok:
            log.info("Bridge inject from chat=%s: %d chars", chat_id, len(text))
        else:
            send_message(chat_id, f"⚠️ 주입 실패: `{result}`")
        return

    sessions = list_sessions(limit=SESSION_LIST_LIMIT)
    send_message(
        chat_id,
        render_session_list_text(sessions, page=0),
        build_main_keyboard(sessions, page=0),
    )


def _handle_signal(_signum: int, _frame: Any) -> None:
    global _running
    log.info("Shutdown signal received.")
    _running = False


def poll_loop() -> None:
    log.info(
        "Bot started. Allowed chats=%s, Executor=%s",
        sorted(ALLOWED_CHATS), EXECUTOR_PATH,
    )
    last_update_id = 0
    bridge_poll_interval = 1.5
    short_poll_seconds = 3

    while _running:
        bridge_active = _bridge is not None and _bridge.is_active()
        if _bridge is not None:
            try:
                forwarded = _bridge.tick()
                if forwarded:
                    log.info("Bridge forwarded %d entries to chat", forwarded)
            except Exception:
                log.exception("bridge.tick crashed; continuing")

        poll_timeout = short_poll_seconds if bridge_active else POLL_TIMEOUT
        try:
            resp = requests.get(
                f"{API_BASE}/getUpdates",
                params={
                    "offset": last_update_id + 1,
                    "timeout": poll_timeout,
                    "allowed_updates": json.dumps(["message", "callback_query"]),
                },
                timeout=poll_timeout + 5,
            )
        except requests.RequestException as exc:
            log.warning("getUpdates failed: %s — backing off", exc)
            time.sleep(3)
            continue

        if resp.status_code != 200:
            log.warning("getUpdates HTTP %s: %s", resp.status_code, resp.text[:200])
            time.sleep(3)
            continue

        try:
            updates = resp.json().get("result", [])
        except ValueError:
            updates = []

        for update in updates:
            uid = update.get("update_id", 0)
            if uid > last_update_id:
                last_update_id = uid
            try:
                handle_update(update)
            except Exception:
                log.exception("Update handler crashed; continuing")

        if bridge_active and not updates:
            time.sleep(bridge_poll_interval)


def _send_to_chat(chat_id: str, text: str) -> dict:
    """Adapter exposed to BridgeManager — handles long text + parse failures."""
    return send_message(chat_id, text)


def _build_health_report() -> str:
    """One-shot diagnostic — returns Markdown summary of system state."""
    import platform, shutil as _sh

    bridge_line = "_미초기화_"
    if _bridge is not None:
        if _bridge.is_active():
            s = _bridge.state
            bridge_line = (
                f"활성 · `{s.session_uuid[:8] if s else '?'}` · "
                f"chat `{s.chat_id if s else '?'}`"
            )
        else:
            bridge_line = "비활성"

    sessions_cnt = len(list_sessions(limit=200))
    tmux_path = _sh.which("tmux") or "_없음_"
    claude_path = _sh.which(os.environ.get("CLAUDE_BIN", "claude")) or "_PATH 외_"
    state_path = Path(
        os.environ.get(
            "TELEGRAM_BRIDGE_STATE_DIR",
            str(Path.home() / ".claude-forge" / "telegram-resume" / "state"),
        )
    )

    return (
        "🩺 *Health check*\n\n"
        f"Bridge: {bridge_line}\n"
        f"Sessions on disk: `{sessions_cnt}`\n"
        f"tmux: `{tmux_path}`\n"
        f"claude CLI: `{claude_path}`\n"
        f"Executor: `{EXECUTOR_PATH}` "
        f"({'OK' if EXECUTOR_PATH.exists() else 'MISSING'})\n"
        f"State dir: `{state_path}` "
        f"({'OK' if state_path.exists() else 'MISSING'})\n"
        f"Allowed chats: `{len(ALLOWED_CHATS)}` ID(s)\n"
        f"Python: `{platform.python_version()}` · {platform.system()} {platform.release()}"
    )


def main() -> None:
    global _bridge
    _setup_logging()
    _check_config()
    signal.signal(signal.SIGINT, _handle_signal)
    signal.signal(signal.SIGTERM, _handle_signal)
    _bridge = BridgeManager(send_message=_send_to_chat)
    if _bridge.is_active():
        log.info("Recovered active bridge from disk: %s", _bridge.state)
    poll_loop()


if __name__ == "__main__":
    main()
