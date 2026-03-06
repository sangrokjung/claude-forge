"""Tests for channels.slack — Slack Block Kit formatting and SlackChannel."""

from __future__ import annotations

import json

import httpx
import pytest

from mobility_rfp_monitor.channels.slack import SlackChannel, format_slack_message
from mobility_rfp_monitor.exceptions import SlackNotificationError
from mobility_rfp_monitor.models import Announcement, AnnouncementSource


def _make_ann(
    id_: str,
    title: str,
    *,
    source: AnnouncementSource = AnnouncementSource.MSS,
    url: str | None = None,
    keywords: frozenset[str] = frozenset({"자율주행"}),
) -> Announcement:
    return Announcement(
        id=id_,
        source=source,
        title=title,
        description="desc",
        url=url if url is not None else f"https://example.com/{id_}",
        published_at="2026-03-01",
        organization="Org",
        matched_keywords=keywords,
    )


class TestFormatSlackMessage:
    def test_structure(self) -> None:
        anns = [_make_ann("a", "Test Title")]
        payload = format_slack_message(anns)
        assert "blocks" in payload
        blocks = payload["blocks"]
        assert blocks[0]["type"] == "header"
        assert "1건" in blocks[0]["text"]["text"]

    def test_multiple_announcements(self) -> None:
        anns = [_make_ann("a", "Title A"), _make_ann("b", "Title B")]
        payload = format_slack_message(anns)
        assert "2건" in payload["blocks"][0]["text"]["text"]

    def test_empty_list(self) -> None:
        payload = format_slack_message([])
        assert len(payload["blocks"]) == 1
        assert "0건" in payload["blocks"][0]["text"]["text"]

    def test_block_limit(self) -> None:
        anns = [_make_ann(f"bulk-{i}", f"공고 {i}") for i in range(50)]
        payload = format_slack_message(anns)
        assert len(payload["blocks"]) <= 50


class TestSlackChannel:
    def test_send_success(self) -> None:
        transport = httpx.MockTransport(lambda req: httpx.Response(200, text="ok"))
        with httpx.Client(transport=transport) as client:
            ch = SlackChannel(client, "https://hooks.slack.com/test")
            assert ch.channel_name == "slack"
            assert ch.send([_make_ann("a", "T")]) == 1

    def test_send_empty(self) -> None:
        transport = httpx.MockTransport(lambda req: httpx.Response(200, text="ok"))
        with httpx.Client(transport=transport) as client:
            ch = SlackChannel(client, "https://hooks.slack.com/test")
            assert ch.send([]) == 0

    def test_send_http_error(self) -> None:
        transport = httpx.MockTransport(lambda req: httpx.Response(500, text="error"))
        with httpx.Client(transport=transport) as client:
            ch = SlackChannel(client, "https://hooks.slack.com/test")
            with pytest.raises(SlackNotificationError):
                ch.send([_make_ann("a", "T")])

    def test_payload_sent_to_correct_url(self) -> None:
        posted_urls: list[str] = []

        def handler(request: httpx.Request) -> httpx.Response:
            posted_urls.append(str(request.url))
            return httpx.Response(200, text="ok")

        transport = httpx.MockTransport(handler)
        with httpx.Client(transport=transport) as client:
            ch = SlackChannel(client, "https://hooks.slack.com/services/T/B/X")
            ch.send([_make_ann("u1", "URL Test")])

        assert posted_urls == ["https://hooks.slack.com/services/T/B/X"]
