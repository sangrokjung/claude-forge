"""Telegram inline keyboard builders for the resume bot.

All callback_data values stay under Telegram's 64-byte cap.
UUIDs are 36 chars, prefixes are short, so we have headroom.
"""

from __future__ import annotations

from sessions import SessionMeta, format_relative_time


PROJECT_ICONS = {
    "darwin": "🐢",
    "claude-forge": "⚙️",
    "emotion-lab": "💗",
    "emotion-lab-v2": "💗",
    "nunchi": "👀",
    "claw3d": "🦾",
    "poc": "🧪",
}

DEFAULT_ICON = "📁"
SESSIONS_PER_PAGE = 5
MAX_BUTTON_TEXT = 60


def pick_icon(project_name: str) -> str:
    """Find a matching icon from project name, else default."""
    key = project_name.lower()
    for name, icon in PROJECT_ICONS.items():
        if name in key:
            return icon
    return DEFAULT_ICON


def truncate_button(text: str, limit: int = MAX_BUTTON_TEXT) -> str:
    """Telegram button labels render best under 60 chars."""
    text = text.strip()
    return text if len(text) <= limit else text[: limit - 1] + "…"


def build_main_keyboard(sessions: list[SessionMeta], page: int = 0) -> dict:
    """Top-level keyboard: ⚡ Latest + per-session rows + utility row."""
    rows: list[list[dict]] = []

    if sessions:
        rows.append([{"text": "⚡ 가장 최근 이어서 작업", "callback_data": "cf:resume:latest"}])

    page_start = page * SESSIONS_PER_PAGE
    page_end = page_start + SESSIONS_PER_PAGE
    visible = sessions[page_start:page_end]

    for idx, session in enumerate(visible, start=page_start + 1):
        icon = pick_icon(session.project_name)
        branch_short = session.git_branch.split("/")[-1] if session.git_branch else "HEAD"
        label = f"▶ {idx}. {icon} {session.project_name} · {branch_short}"
        rows.append([
            {
                "text": truncate_button(label),
                "callback_data": f"cf:resume:{session.uuid}",
            }
        ])

    nav_row: list[dict] = []
    if page > 0:
        nav_row.append({"text": "◀️ 이전", "callback_data": f"cf:list:page={page - 1}"})
    if page_end < len(sessions):
        nav_row.append({"text": "다음 ▶️", "callback_data": f"cf:list:page={page + 1}"})
    if nav_row:
        rows.append(nav_row)

    rows.append([
        {"text": "🔄 새로고침", "callback_data": "cf:list:refresh"},
        {"text": "🔍 검색", "switch_inline_query_current_chat": ""},
        {"text": "⚙️ 설정", "callback_data": "cf:settings"},
    ])

    return {"inline_keyboard": rows}


def build_confirm_keyboard(uuid: str) -> dict:
    """Confirmation screen after picking one session."""
    short = uuid[:8]
    return {
        "inline_keyboard": [
            [
                {"text": "✅ 이어서 작업", "callback_data": f"cf:exec:r:{short}"},
                {"text": "❌ 취소", "callback_data": "cf:cancel"},
            ],
            [
                {"text": "🍴 새 세션으로 fork", "callback_data": f"cf:exec:f:{short}"},
            ],
            [
                {"text": "🖥️ Remote Control로 열기", "callback_data": f"cf:exec:rc:{short}"},
            ],
        ]
    }


def build_single_resume_keyboard(uuid: str) -> dict:
    """Single-button keyboard for Stop-hook notifications."""
    return {
        "inline_keyboard": [
            [{"text": "↩️ 이 세션 이어서 작업", "callback_data": f"cf:resume:{uuid}"}]
        ]
    }


def build_post_exec_keyboard() -> dict:
    """Buttons shown after executor has been triggered."""
    return {
        "inline_keyboard": [
            [
                {"text": "📋 세션 목록", "callback_data": "cf:list:refresh"},
                {"text": "⚙️ 설정", "callback_data": "cf:settings"},
            ]
        ]
    }


def render_session_list_text(sessions: list[SessionMeta], page: int = 0) -> str:
    """Markdown body for the main session list message."""
    if not sessions:
        return (
            "🤖 *Claude Code · 세션 이어서 작업*\n\n"
            "_최근 세션을 찾지 못했습니다._\n"
            "`~/.claude/projects/` 가 비어 있거나, "
            "claude-forge가 처음 설정된 상태일 수 있습니다."
        )

    page_start = page * SESSIONS_PER_PAGE
    page_end = page_start + SESSIONS_PER_PAGE
    visible = sessions[page_start:page_end]
    total_pages = (len(sessions) + SESSIONS_PER_PAGE - 1) // SESSIONS_PER_PAGE

    header = f"🤖 *Claude Code · 세션 이어서 작업*\n\n_최근 활성 세션 {len(sessions)}개 발견_"
    if total_pages > 1:
        header += f"  ·  페이지 {page + 1}/{total_pages}"

    lines = [header, ""]
    for idx, s in enumerate(visible, start=page_start + 1):
        icon = pick_icon(s.project_name)
        branch_short = s.git_branch.split("/")[-1] if s.git_branch else "HEAD"
        rel = format_relative_time(s.last_activity_iso)
        preview = s.first_prompt_preview or "_미리보기 없음_"
        lines.append(f"*{idx}. {icon} {s.project_name}* · `{branch_short}`")
        lines.append(f"   {rel} · {s.turn_count}턴 · _\"{preview}\"_")
        lines.append("")

    return "\n".join(lines).rstrip()


def render_confirm_text(meta: SessionMeta, mode: str = "resume") -> str:
    """Markdown body for the confirmation screen."""
    icon = pick_icon(meta.project_name)
    rel = format_relative_time(meta.last_activity_iso)
    mode_label = {
        "resume": "▶ 이어가기",
        "fork": "🍴 새 세션으로 fork",
        "rc": "🖥️ Remote Control로 열기",
    }.get(mode, mode)

    branch = meta.git_branch or "HEAD"
    preview = meta.first_prompt_preview or "_미리보기 없음_"

    return (
        f"*{mode_label}*: {icon} {meta.project_name}\n"
        f"브랜치: `{branch}`\n"
        f"마지막 활동: {rel}  ·  {meta.turn_count}턴\n\n"
        f"_첫 메시지:_\n_\"{preview}\"_\n\n"
        f"실행 경로: `{meta.cwd or '(unknown)'}`"
    )


if __name__ == "__main__":
    import json
    from sessions import list_sessions

    sessions = list_sessions(limit=10)
    print("=== render_session_list_text ===")
    print(render_session_list_text(sessions, page=0))
    print()
    print("=== build_main_keyboard ===")
    print(json.dumps(build_main_keyboard(sessions, page=0), indent=2, ensure_ascii=False))
