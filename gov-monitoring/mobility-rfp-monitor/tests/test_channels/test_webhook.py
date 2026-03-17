"""Tests for channels.webhook — Generic JSON webhook channel."""

from __future__ import annotations

import json

import httpx
import pytest

from mobility_rfp_monitor.channels.webhook import WebhookChannel
from mobility_rfp_monitor.exceptions import WebhookNotificationError
from mobility_rfp_monitor.models import Announcement, AnnouncementSource


def _make_ann(id_: str, title: str) -> Announcement:
    return Announcement(
        id=id_,
        source=AnnouncementSource.G2B_BID,
        title=title,
        description="desc",
        url=f"https://example.com/{id_}",
        published_at="2026-03-01",
        organization="Org",
        matched_keywords=frozenset({"전기차"}),
    )


class TestWebhookChannel:
    def test_send_success(self) -> None:
        captured: list[bytes] = []

        def handler(request: httpx.Request) -> httpx.Response:
            captured.append(request.content)
            return httpx.Response(200, text="ok")

        transport = httpx.MockTransport(handler)
        with httpx.Client(transport=transport) as client:
            ch = WebhookChannel(client, "https://example.com/webhook")
            assert ch.channel_name == "webhook"
            assert ch.send([_make_ann("a", "T")]) == 1

        body = json.loads(captured[0])
        assert body["event"] == "mobility_rfp_alert"
        assert body["total"] == 1
        assert len(body["announcements"]) == 1
        assert body["announcements"][0]["title"] == "T"

    def test_send_empty(self) -> None:
        transport = httpx.MockTransport(lambda req: httpx.Response(200))
        with httpx.Client(transport=transport) as client:
            ch = WebhookChannel(client, "https://example.com/webhook")
            assert ch.send([]) == 0

    def test_send_http_error(self) -> None:
        transport = httpx.MockTransport(lambda req: httpx.Response(500, text="error"))
        with httpx.Client(transport=transport) as client:
            ch = WebhookChannel(client, "https://example.com/webhook")
            with pytest.raises(WebhookNotificationError):
                ch.send([_make_ann("a", "T")])

    def test_custom_headers(self) -> None:
        captured_headers: list[dict[str, str]] = []

        def handler(request: httpx.Request) -> httpx.Response:
            captured_headers.append(dict(request.headers))
            return httpx.Response(200)

        transport = httpx.MockTransport(handler)
        with httpx.Client(transport=transport) as client:
            ch = WebhookChannel(
                client,
                "https://example.com/webhook",
                headers={"X-Custom": "test-value"},
            )
            ch.send([_make_ann("a", "T")])

        assert captured_headers[0].get("x-custom") == "test-value"

    def test_announcement_serialization(self) -> None:
        captured: list[bytes] = []

        def handler(request: httpx.Request) -> httpx.Response:
            captured.append(request.content)
            return httpx.Response(200)

        transport = httpx.MockTransport(handler)
        with httpx.Client(transport=transport) as client:
            ch = WebhookChannel(client, "https://example.com/webhook")
            ch.send([_make_ann("ser-1", "직렬화 테스트")])

        body = json.loads(captured[0])
        ann = body["announcements"][0]
        assert ann["id"] == "ser-1"
        assert ann["source"] == "g2b_bid"
        assert ann["matched_keywords"] == ["전기차"]
