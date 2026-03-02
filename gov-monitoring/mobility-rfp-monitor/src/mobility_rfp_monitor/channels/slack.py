"""Slack webhook channel — Block Kit formatted notifications."""

from __future__ import annotations

from typing import Any, Sequence

import httpx

from mobility_rfp_monitor.exceptions import SlackNotificationError
from mobility_rfp_monitor.models import Announcement

_SOURCE_LABELS = {
    "mss": "중기부 기술개발",
    "g2b_bid": "나라장터 입찰",
}

_SLACK_MAX_BLOCKS = 50


def _announcement_block(ann: Announcement) -> list[dict[str, Any]]:
    source_label = _SOURCE_LABELS.get(ann.source.value, ann.source.value)
    keywords = ", ".join(sorted(ann.matched_keywords)) if ann.matched_keywords else "-"
    lines = [
        f"*<{ann.url}|{ann.title}>*" if ann.url else f"*{ann.title}*",
        f"_{source_label}_ | {ann.organization} | {ann.published_at}",
        f"Keywords: `{keywords}`",
    ]
    return [
        {"type": "section", "text": {"type": "mrkdwn", "text": "\n".join(lines)}},
        {"type": "divider"},
    ]


def format_slack_message(announcements: Sequence[Announcement]) -> dict[str, Any]:
    """Build a Slack Block Kit payload.

    Respects the 50-block limit; truncates with a footer when needed.
    """
    total = len(announcements)
    blocks: list[dict[str, Any]] = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": f"Mobility RFP Alert ({total}건)",
            },
        },
    ]
    shown = 0
    for ann in announcements:
        candidate = _announcement_block(ann)
        limit = _SLACK_MAX_BLOCKS - 1 if shown < total else _SLACK_MAX_BLOCKS
        if len(blocks) + len(candidate) > limit:
            break
        blocks.extend(candidate)
        shown += 1
    if shown < total:
        remaining = total - shown
        blocks.append(
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"_... 외 {remaining}건 생략_",
                },
            }
        )
    return {"blocks": blocks}


class SlackChannel:
    """Slack Incoming Webhook notification channel."""

    def __init__(self, http_client: httpx.Client, webhook_url: str) -> None:
        self._client = http_client
        self._webhook_url = webhook_url

    @property
    def channel_name(self) -> str:
        return "slack"

    def send(self, announcements: Sequence[Announcement]) -> int:
        if not announcements:
            return 0
        payload = format_slack_message(announcements)
        resp = self._client.post(self._webhook_url, json=payload)
        if resp.status_code != 200:
            raise SlackNotificationError(resp.status_code, resp.text[:200])
        return len(announcements)
