"""Generic webhook notification channel — JSON POST to any endpoint."""

from __future__ import annotations

from typing import Any, Sequence

import httpx

from mobility_rfp_monitor.exceptions import WebhookNotificationError
from mobility_rfp_monitor.models import Announcement


def _serialize_announcement(ann: Announcement) -> dict[str, Any]:
    return {
        "id": ann.id,
        "source": ann.source.value,
        "title": ann.title,
        "description": ann.description,
        "url": ann.url,
        "published_at": ann.published_at,
        "organization": ann.organization,
        "matched_keywords": sorted(ann.matched_keywords),
    }


class WebhookChannel:
    """Generic HTTP POST webhook notification channel."""

    def __init__(
        self,
        http_client: httpx.Client,
        webhook_url: str,
        *,
        headers: dict[str, str] | None = None,
    ) -> None:
        self._client = http_client
        self._webhook_url = webhook_url
        self._headers = headers or {}

    @property
    def channel_name(self) -> str:
        return "webhook"

    def send(self, announcements: Sequence[Announcement]) -> int:
        if not announcements:
            return 0

        payload = {
            "event": "mobility_rfp_alert",
            "total": len(announcements),
            "announcements": [_serialize_announcement(ann) for ann in announcements],
        }
        resp = self._client.post(
            self._webhook_url,
            json=payload,
            headers=self._headers,
        )
        if resp.status_code >= 400:
            raise WebhookNotificationError(resp.status_code, resp.text[:200])

        return len(announcements)
