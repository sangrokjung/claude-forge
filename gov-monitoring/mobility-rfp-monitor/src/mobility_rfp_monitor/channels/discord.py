"""Discord webhook notification channel — Embed formatted notifications."""

from __future__ import annotations

from typing import Any, Sequence

import httpx

from mobility_rfp_monitor.exceptions import DiscordNotificationError
from mobility_rfp_monitor.models import Announcement

_SOURCE_LABELS = {
    "mss": "중기부 기술개발",
    "g2b_bid": "나라장터 입찰",
}

_DISCORD_MAX_EMBEDS = 10


def _build_embed(ann: Announcement) -> dict[str, Any]:
    source_label = _SOURCE_LABELS.get(ann.source.value, ann.source.value)
    keywords = ", ".join(sorted(ann.matched_keywords)) if ann.matched_keywords else "-"
    embed: dict[str, Any] = {
        "title": ann.title[:256],
        "color": 0x0099FF,
        "fields": [
            {"name": "소스", "value": source_label, "inline": True},
            {"name": "기관", "value": ann.organization or "-", "inline": True},
            {"name": "공고일", "value": ann.published_at or "-", "inline": True},
            {"name": "키워드", "value": keywords, "inline": False},
        ],
    }
    if ann.url:
        embed["url"] = ann.url
    return embed


def _build_payloads(announcements: Sequence[Announcement]) -> list[dict[str, Any]]:
    """Split announcements into Discord-safe batches (max 10 embeds each)."""
    total = len(announcements)
    payloads: list[dict[str, Any]] = []

    for batch_start in range(0, total, _DISCORD_MAX_EMBEDS):
        batch = announcements[batch_start : batch_start + _DISCORD_MAX_EMBEDS]
        embeds = [_build_embed(ann) for ann in batch]
        content = f"**Mobility RFP Alert** ({total}건)" if batch_start == 0 else ""
        payload: dict[str, Any] = {"embeds": embeds}
        if content:
            payload["content"] = content
        payloads.append(payload)

    return payloads


class DiscordChannel:
    """Discord Incoming Webhook notification channel."""

    def __init__(self, http_client: httpx.Client, webhook_url: str) -> None:
        self._client = http_client
        self._webhook_url = webhook_url

    @property
    def channel_name(self) -> str:
        return "discord"

    def send(self, announcements: Sequence[Announcement]) -> int:
        if not announcements:
            return 0

        payloads = _build_payloads(announcements)
        for payload in payloads:
            resp = self._client.post(self._webhook_url, json=payload)
            if resp.status_code not in (200, 204):
                raise DiscordNotificationError(resp.status_code, resp.text[:200])

        return len(announcements)
