"""Bridge mode — pipe a live Claude Code session through Telegram.

State machine:
    INACTIVE  ─ /tg trigger ──►  ACTIVE  ─ /end ──►  INACTIVE
                                   │
                                   └─ idle timeout ──► INACTIVE
                                   └─ Stop hook ─────► INACTIVE

Output flow (Mac → phone):
    Claude writes turn → jsonl file
        bridge tails jsonl
            new assistant entry?
                → format markdown
                → send_fn(chat_id, text)

Input flow (phone → Mac):
    User types in Telegram
        bot handle_text(chat_id, msg)
            if bridge.is_active:
                bridge.inject(msg)  → tmux send-keys

State persistence:
    ~/.claude-forge/telegram-resume/state/bridge.json
    Reloaded on bot restart (jsonl_size_at_start prevents replay).
"""

from __future__ import annotations

import json
import logging
import os
import shutil
import subprocess
import time
from dataclasses import dataclass, asdict, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Callable, Optional


STATE_DIR = Path(
    os.environ.get(
        "TELEGRAM_BRIDGE_STATE_DIR",
        str(Path.home() / ".claude-forge" / "telegram-resume" / "state"),
    )
).expanduser()
STATE_FILE = STATE_DIR / "bridge.json"
MAX_IDLE_MIN = int(os.environ.get("TELEGRAM_BRIDGE_MAX_IDLE_MIN", "90"))
MAX_TG_MESSAGE = 3800  # safe under 4096 to allow our header
MAX_OUTPUT_BURST = int(os.environ.get("TELEGRAM_BRIDGE_MAX_BURST", "8"))

# Telegram legacy-Markdown special chars that need escaping in arbitrary
# text content (the parser will silently reject the whole message on
# unbalanced/invalid sequences).  We deliberately keep backticks unescaped
# inside fenced code blocks via _format_text_block().
_MD_LEGACY_ESCAPE = ("\\", "_", "*", "`", "[")


def escape_md(text: str) -> str:
    """Minimal escape for Telegram legacy-Markdown content.

    Escapes everything that the parser treats as a control character,
    so Claude output that contains `_my_var_`, `*foo*`, `[x](y)` etc.
    still reaches the user instead of getting silently dropped.
    """
    for ch in _MD_LEGACY_ESCAPE:
        text = text.replace(ch, "\\" + ch)
    return text

log = logging.getLogger("telegram-bridge")


@dataclass
class BridgeState:
    """Immutable-ish handle to the active bridge, persisted to disk."""

    session_uuid: str
    jsonl_path: str
    tmux_target: str
    chat_id: str
    started_at: str
    jsonl_size_at_start: int = 0
    last_activity_at: str = ""
    project_name: str = ""
    git_branch: str = ""

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: dict) -> "BridgeState":
        return cls(**{k: d.get(k, "") for k in cls.__dataclass_fields__})


@dataclass
class _Stats:
    sent_count: int = 0
    injected_count: int = 0
    errors: list[str] = field(default_factory=list)


class BridgeManager:
    """Owns the live bridge state and pumps the jsonl ↔ tmux channel."""

    def __init__(
        self,
        send_message: Callable[[str, str], dict],
        state_file: Path = STATE_FILE,
    ) -> None:
        self.send_message = send_message
        self.state_file = state_file
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        self._state: Optional[BridgeState] = None
        self._jsonl_pos: int = 0
        self._stats = _Stats()
        self._state_mtime: float = 0.0
        self.reload_state()

    # ---------------------------------------------------------------- state

    def is_active(self) -> bool:
        return self._state is not None

    @property
    def state(self) -> Optional[BridgeState]:
        return self._state

    def reload_state(self) -> None:
        """Pick up changes from disk (e.g. written by the handoff hook)."""
        if not self.state_file.exists():
            if self._state is not None:
                log.info("State file gone — deactivating bridge.")
                self._state = None
                self._jsonl_pos = 0
            self._state_mtime = 0.0
            return

        try:
            mtime = self.state_file.stat().st_mtime
        except OSError:
            return
        if mtime == self._state_mtime and self._state is not None:
            return

        try:
            data = json.loads(self.state_file.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            log.warning("Failed to read state file %s: %s", self.state_file, exc)
            return

        if not data.get("active", True):
            self._state = None
            self._jsonl_pos = 0
            self._state_mtime = mtime
            return

        new_state = BridgeState.from_dict(data)
        is_new_session = (
            self._state is None or self._state.session_uuid != new_state.session_uuid
        )
        self._state = new_state
        self._state_mtime = mtime
        if is_new_session:
            self._jsonl_pos = new_state.jsonl_size_at_start
            log.info(
                "Bridge ACTIVATED: session=%s chat=%s tmux=%s",
                new_state.session_uuid[:8], new_state.chat_id, new_state.tmux_target,
            )

    def save_state(self) -> None:
        if self._state is None:
            try:
                self.state_file.unlink(missing_ok=True)
            except OSError:
                pass
            self._state_mtime = 0.0
            return
        payload = self._state.to_dict()
        payload["active"] = True
        tmp = self.state_file.with_suffix(".tmp")
        tmp.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
        tmp.replace(self.state_file)
        try:
            self._state_mtime = self.state_file.stat().st_mtime
        except OSError:
            pass

    def start(
        self,
        *,
        session_uuid: str,
        jsonl_path: str,
        tmux_target: str,
        chat_id: str,
        project_name: str = "",
        git_branch: str = "",
    ) -> BridgeState:
        path = Path(jsonl_path).expanduser()
        size = path.stat().st_size if path.exists() else 0
        now = datetime.now(timezone.utc).isoformat()
        self._state = BridgeState(
            session_uuid=session_uuid,
            jsonl_path=str(path),
            tmux_target=tmux_target,
            chat_id=str(chat_id),
            started_at=now,
            jsonl_size_at_start=size,
            last_activity_at=now,
            project_name=project_name,
            git_branch=git_branch,
        )
        self._jsonl_pos = size
        self.save_state()
        log.info("Bridge started for %s (chat=%s)", session_uuid[:8], chat_id)
        return self._state

    def stop(self, reason: str = "manual") -> Optional[BridgeState]:
        prev = self._state
        self._state = None
        self._jsonl_pos = 0
        try:
            self.state_file.unlink(missing_ok=True)
        except OSError:
            pass
        self._state_mtime = 0.0
        log.info("Bridge stopped (%s).", reason)
        return prev

    # -------------------------------------------------------------- inject

    def inject(self, text: str) -> tuple[bool, str]:
        """Push a user message into the bridged tmux pane.

        Single-line text goes through `send-keys -l` (literal).  Multi-line
        text goes through `load-buffer` + `paste-buffer` so each newline
        becomes a real Enter (Claude Code's TUI handles bracketed paste
        correctly via this path).
        """
        if not self._state:
            return False, "no bridge active"
        if not shutil.which("tmux"):
            return False, "tmux not found"
        target = self._state.tmux_target
        if not target:
            return False, "no tmux target"

        try:
            result = subprocess.run(
                ["tmux", "has-session", "-t", target],
                capture_output=True, text=True, timeout=3,
            )
            if result.returncode != 0:
                return False, f"tmux session '{target}' not found"
        except (OSError, subprocess.TimeoutExpired) as exc:
            return False, f"tmux check failed: {exc}"

        try:
            if "\n" in text:
                # Multi-line: use the paste buffer so each newline is honored
                # as Enter inside whatever app owns the pane.
                subprocess.run(
                    ["tmux", "load-buffer", "-b", "cf-bridge", "-"],
                    input=text, text=True,
                    check=True, capture_output=True, timeout=5,
                )
                subprocess.run(
                    ["tmux", "paste-buffer", "-b", "cf-bridge", "-d", "-t", target],
                    check=True, capture_output=True, text=True, timeout=5,
                )
                subprocess.run(
                    ["tmux", "send-keys", "-t", target, "Enter"],
                    check=True, capture_output=True, text=True, timeout=5,
                )
            else:
                # Single-line happy path — minimal overhead.
                subprocess.run(
                    ["tmux", "send-keys", "-t", target, "-l", text],
                    check=True, capture_output=True, text=True, timeout=5,
                )
                subprocess.run(
                    ["tmux", "send-keys", "-t", target, "Enter"],
                    check=True, capture_output=True, text=True, timeout=5,
                )
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as exc:
            return False, f"send-keys failed: {exc}"

        self._touch_activity()
        self._stats.injected_count += 1
        return True, "injected"

    def _touch_activity(self) -> None:
        if not self._state:
            return
        self._state.last_activity_at = datetime.now(timezone.utc).isoformat()
        self.save_state()

    def _notify_safe(self, chat_id: str, text: str) -> None:
        try:
            self.send_message(chat_id, text)
        except Exception:  # noqa: BLE001
            log.exception("send_message raised; suppressing")

    # --------------------------------------------------------------- tail

    def tick(self) -> int:
        """Called from the bot poll loop.  Returns # of messages forwarded."""
        self.reload_state()
        if not self._state:
            return 0

        if self._check_idle_timeout():
            self._notify_safe(
                self._state.chat_id,
                f"🛑 Bridge 자동 종료 (idle {MAX_IDLE_MIN}분 초과)",
            )
            self.stop(reason="idle-timeout")
            return 0

        return self._forward_new_jsonl()

    def _check_idle_timeout(self) -> bool:
        if not self._state or not self._state.last_activity_at:
            return False
        try:
            last = datetime.fromisoformat(self._state.last_activity_at.replace("Z", "+00:00"))
        except ValueError:
            return False
        idle_sec = (datetime.now(timezone.utc) - last).total_seconds()
        return idle_sec > MAX_IDLE_MIN * 60

    def _forward_new_jsonl(self) -> int:
        if not self._state:
            return 0
        path = Path(self._state.jsonl_path)
        if not path.exists():
            self._notify_safe(
                self._state.chat_id,
                "🚨 _세션 jsonl이 사라졌습니다 — Claude 종료 추정. Bridge 자동 해제._",
            )
            self.stop(reason="jsonl-missing")
            return 0

        # Detect tmux session vanishing (e.g. user killed it from Mac).
        if shutil.which("tmux") and self._state.tmux_target:
            try:
                tmux_check = subprocess.run(
                    ["tmux", "has-session", "-t", self._state.tmux_target],
                    capture_output=True, text=True, timeout=3,
                )
                if tmux_check.returncode != 0:
                    self._notify_safe(
                        self._state.chat_id,
                        f"🚨 _tmux 세션 \\`{self._state.tmux_target}\\`이 사라졌습니다 — "
                        "Bridge 자동 해제._",
                    )
                    self.stop(reason="tmux-gone")
                    return 0
            except (OSError, subprocess.TimeoutExpired):
                pass  # transient — keep going

        try:
            current_size = path.stat().st_size
        except OSError:
            return 0

        if current_size < self._jsonl_pos:
            log.warning("jsonl shrank (%d → %d); resetting tail.", self._jsonl_pos, current_size)
            self._jsonl_pos = current_size
            return 0

        if current_size == self._jsonl_pos:
            return 0

        try:
            with path.open("rb") as fp:
                fp.seek(self._jsonl_pos)
                new_bytes = fp.read(current_size - self._jsonl_pos)
                self._jsonl_pos = fp.tell()
        except OSError as exc:
            log.warning("jsonl read failed: %s", exc)
            return 0

        try:
            new_text = new_bytes.decode("utf-8", errors="replace")
        except Exception:  # noqa: BLE001
            return 0

        forwarded = 0
        for line in new_text.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError:
                continue
            chunks = self._format_entry(entry)
            for chunk in chunks:
                if not chunk:
                    continue
                if forwarded >= MAX_OUTPUT_BURST:
                    self._notify_safe(
                        self._state.chat_id,
                        "_…(burst limit; 더 받으려면 잠시 대기)_",
                    )
                    return forwarded
                self._notify_safe(self._state.chat_id, chunk)
                self._stats.sent_count += 1
                forwarded += 1

        if forwarded:
            self._touch_activity()
        return forwarded

    # ------------------------------------------------------------- format

    @staticmethod
    def _split_for_telegram(text: str) -> list[str]:
        if len(text) <= MAX_TG_MESSAGE:
            return [text]
        chunks: list[str] = []
        remaining = text
        idx = 1
        total = (len(text) + MAX_TG_MESSAGE - 1) // MAX_TG_MESSAGE
        while remaining:
            head = remaining[:MAX_TG_MESSAGE]
            chunks.append(f"_({idx}/{total})_\n{head}")
            remaining = remaining[MAX_TG_MESSAGE:]
            idx += 1
        return chunks

    @classmethod
    def _format_entry(cls, entry: dict) -> list[str]:
        etype = entry.get("type")
        if etype != "assistant":
            return []
        msg = entry.get("message") or {}
        content = msg.get("content")
        if isinstance(content, str):
            body = escape_md(content.strip())
            return cls._split_for_telegram(f"🤖 *Claude*\n{body}") if body else []

        if not isinstance(content, list):
            return []

        parts: list[str] = []
        for block in content:
            if not isinstance(block, dict):
                continue
            btype = block.get("type")
            if btype == "text":
                text = (block.get("text") or "").strip()
                if text:
                    parts.append(escape_md(text))
            elif btype == "tool_use":
                tool_name_raw = block.get("name") or "tool"
                tool_name = escape_md(tool_name_raw)
                args = block.get("input") or {}
                hint = cls._tool_hint(tool_name_raw, args)
                parts.append(f"🔧 _{tool_name}_{hint}")
            elif btype == "thinking":
                parts.append("💭 _thinking..._")

        if not parts:
            return []
        body = "\n".join(parts)
        return cls._split_for_telegram(f"🤖 *Claude*\n{body}")

    @staticmethod
    def _tool_hint(tool: str, args: dict) -> str:
        if not isinstance(args, dict):
            return ""
        for key in ("file_path", "path", "command", "url", "pattern"):
            if key in args and args[key]:
                value = str(args[key])
                if len(value) > 60:
                    value = value[:57] + "…"
                # Backticks inside a backtick-quoted value would break parsing
                value = value.replace("`", "ˋ")  # modifier letter grave accent
                return f": `{value}`"
        return ""

    # ----------------------------------------------------------- summary

    def status_text(self) -> str:
        if not self._state:
            return "_Bridge 비활성_"
        s = self._state
        try:
            started = datetime.fromisoformat(s.started_at.replace("Z", "+00:00"))
            elapsed = (datetime.now(timezone.utc) - started).total_seconds()
            elapsed_str = f"{int(elapsed // 60)}분" if elapsed >= 60 else f"{int(elapsed)}초"
        except ValueError:
            elapsed_str = "?"
        return (
            "🔌 *Bridge 활성*\n"
            f"세션: `{s.session_uuid[:8]}` · {s.project_name or '?'} · `{s.git_branch or 'HEAD'}`\n"
            f"tmux: `{s.tmux_target}`\n"
            f"경과: {elapsed_str}\n"
            f"전송: {self._stats.sent_count}  ·  주입: {self._stats.injected_count}"
        )


if __name__ == "__main__":
    import sys
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    captured: list[tuple[str, str]] = []

    def fake_send(chat_id: str, text: str) -> dict:
        captured.append((chat_id, text))
        print(f"---> chat={chat_id}\n{text}\n")
        return {"ok": True}

    bm = BridgeManager(send_message=fake_send)
    print("Initial state:", bm.is_active())
    print(bm.status_text())

    if len(sys.argv) > 1:
        cmd = sys.argv[1]
        if cmd == "demo-format":
            # Replay last N entries from a jsonl as if they were freshly written
            from sessions import list_sessions
            sessions = list_sessions(limit=1)
            if not sessions:
                print("no sessions; aborting demo")
                sys.exit(1)
            s = sessions[0]
            print(f"\nLoading: {s.uuid[:8]} · {s.project_name}\n")
            path = Path(s.cwd) if False else Path.home() / ".claude" / "projects"
            jsonl = None
            for slug in path.iterdir():
                cand = slug / f"{s.uuid}.jsonl"
                if cand.exists():
                    jsonl = cand
                    break
            if not jsonl:
                print("jsonl not found")
                sys.exit(1)
            with jsonl.open() as fp:
                lines = fp.readlines()
            for line in lines[-20:]:
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                for chunk in BridgeManager._format_entry(entry):
                    print(chunk)
                    print("---")
