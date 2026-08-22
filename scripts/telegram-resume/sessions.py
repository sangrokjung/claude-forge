"""Claude Code session metadata loader.

Reads ~/.claude/projects/<slug>/<uuid>.jsonl files and extracts
session metadata (project path, branch, last activity, first user prompt).

Designed for fast loading — only reads first ~5 lines and last ~5 lines
of each jsonl file rather than parsing the entire transcript.
"""

from __future__ import annotations

import json
import os
from collections import deque
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from pathlib import Path


CLAUDE_PROJECTS_DIR = Path.home() / ".claude" / "projects"
MAX_PREVIEW_CHARS = 80
HEAD_LINES = 8
TAIL_LINES = 8


@dataclass(frozen=True)
class SessionMeta:
    """Immutable metadata snapshot for one Claude Code session."""

    uuid: str
    cwd: str
    git_branch: str
    last_activity_iso: str
    last_activity_epoch: float
    first_prompt_preview: str
    turn_count: int
    project_name: str
    slug: str

    def to_dict(self) -> dict:
        return asdict(self)


def _read_head_tail(path: Path, head: int = HEAD_LINES, tail: int = TAIL_LINES) -> tuple[list[str], list[str]]:
    """Read first N and last N lines without loading entire file."""
    head_lines: list[str] = []
    tail_dq: deque[str] = deque(maxlen=tail)
    with path.open("r", encoding="utf-8", errors="replace") as fp:
        for i, line in enumerate(fp):
            if i < head:
                head_lines.append(line)
            tail_dq.append(line)
    return head_lines, list(tail_dq)


def _safe_json(line: str) -> dict | None:
    try:
        return json.loads(line)
    except (json.JSONDecodeError, ValueError):
        return None


def _extract_user_text(entry: dict) -> str:
    """Pull text from user-message entries with several shape variants."""
    if entry.get("type") == "queue-operation":
        return str(entry.get("content", "")).strip()

    if entry.get("type") == "user":
        msg = entry.get("message")
        if isinstance(msg, dict):
            content = msg.get("content", "")
            if isinstance(content, str):
                return content.strip()
            if isinstance(content, list):
                parts = [
                    str(c.get("text", ""))
                    for c in content
                    if isinstance(c, dict) and c.get("type") == "text"
                ]
                return " ".join(p for p in parts if p).strip()
    return ""


def _truncate(text: str, n: int = MAX_PREVIEW_CHARS) -> str:
    text = " ".join(text.split())
    return text if len(text) <= n else text[: n - 1] + "…"


def load_session_meta(jsonl_path: Path) -> SessionMeta | None:
    """Parse one .jsonl into SessionMeta. Returns None if unparseable."""
    if not jsonl_path.exists() or jsonl_path.stat().st_size == 0:
        return None

    try:
        head_lines, tail_lines = _read_head_tail(jsonl_path)
    except OSError:
        return None

    head = [e for line in head_lines if (e := _safe_json(line))]
    tail = [e for line in tail_lines if (e := _safe_json(line))]

    if not head and not tail:
        return None

    uuid = jsonl_path.stem
    cwd = ""
    git_branch = ""
    for entry in tail + head:
        if entry.get("cwd"):
            cwd = entry["cwd"]
            break
    for entry in tail + head:
        if entry.get("gitBranch"):
            git_branch = entry["gitBranch"]
            break

    last_iso = ""
    for entry in reversed(tail):
        if entry.get("timestamp"):
            last_iso = entry["timestamp"]
            break
    if not last_iso:
        mtime = jsonl_path.stat().st_mtime
        last_iso = datetime.fromtimestamp(mtime, tz=timezone.utc).isoformat()

    try:
        last_epoch = datetime.fromisoformat(last_iso.replace("Z", "+00:00")).timestamp()
    except ValueError:
        last_epoch = jsonl_path.stat().st_mtime

    first_prompt = ""
    for entry in head:
        text = _extract_user_text(entry)
        if text:
            first_prompt = _truncate(text)
            break

    project_name = Path(cwd).name if cwd else uuid[:8]
    slug = jsonl_path.parent.name

    turn_count = 0
    try:
        with jsonl_path.open("rb") as fp:
            turn_count = sum(1 for _ in fp)
    except OSError:
        pass

    return SessionMeta(
        uuid=uuid,
        cwd=cwd,
        git_branch=git_branch,
        last_activity_iso=last_iso,
        last_activity_epoch=last_epoch,
        first_prompt_preview=first_prompt,
        turn_count=turn_count,
        project_name=project_name,
        slug=slug,
    )


def list_sessions(limit: int = 50, projects_dir: Path | None = None) -> list[SessionMeta]:
    """Return up to `limit` sessions, sorted by most-recent activity first."""
    root = projects_dir or CLAUDE_PROJECTS_DIR
    if not root.exists():
        return []

    candidates: list[Path] = []
    for slug_dir in root.iterdir():
        if not slug_dir.is_dir():
            continue
        candidates.extend(slug_dir.glob("*.jsonl"))

    candidates.sort(key=lambda p: p.stat().st_mtime, reverse=True)
    candidates = candidates[: max(limit * 2, limit)]

    metas: list[SessionMeta] = []
    for path in candidates:
        meta = load_session_meta(path)
        if meta:
            metas.append(meta)
        if len(metas) >= limit:
            break

    metas.sort(key=lambda m: m.last_activity_epoch, reverse=True)
    return metas[:limit]


def find_session(uuid: str, projects_dir: Path | None = None) -> SessionMeta | None:
    """Lookup a single session by UUID prefix or full UUID."""
    root = projects_dir or CLAUDE_PROJECTS_DIR
    if not root.exists():
        return None

    for slug_dir in root.iterdir():
        if not slug_dir.is_dir():
            continue
        for jsonl_path in slug_dir.glob(f"{uuid}*.jsonl"):
            meta = load_session_meta(jsonl_path)
            if meta:
                return meta
    return None


def format_relative_time(iso_ts: str) -> str:
    """'2분 전', '1시간 전', '어제', '3일 전' style."""
    try:
        ts = datetime.fromisoformat(iso_ts.replace("Z", "+00:00"))
    except ValueError:
        return "?"
    now = datetime.now(timezone.utc)
    delta = now - ts
    secs = int(delta.total_seconds())
    if secs < 60:
        return "방금"
    if secs < 3600:
        return f"{secs // 60}분 전"
    if secs < 86_400:
        return f"{secs // 3600}시간 전"
    if secs < 172_800:
        return "어제"
    if secs < 604_800:
        return f"{secs // 86_400}일 전"
    return ts.strftime("%Y-%m-%d")


if __name__ == "__main__":
    import sys

    sessions = list_sessions(limit=10)
    print(f"Found {len(sessions)} sessions\n")
    for s in sessions:
        rel = format_relative_time(s.last_activity_iso)
        print(f"  {s.project_name:30s} {s.git_branch:30s} {rel:10s} {s.uuid[:8]}")
        if s.first_prompt_preview:
            print(f"    └─ {s.first_prompt_preview[:60]}")
    sys.exit(0)
