"""Tests for channels.discord — Discord embed formatting and DiscordChannel."""

from __future__ import annotations

import json

import httpx
import pytest

from mobility_rfp_monitor.channels.discord import DiscordChannel, _build_payloads
from mobility_rfp_monitor.exceptions import DiscordNotificationError
from mobility_rfp_monitor.models import Announcement, AnnouncementSource


def _make_ann(id_: str, title: str) -> Announcement:
    return Announcement(
        id=id_,
        source=AnnouncementSource.MSS,
        title=title,
        description="desc",
        url=f"https://example.com/{id_}",
        published_at="2026-03-01",
        organization="Org",
        matched_keywords=frozenset({"자율주행"}),
    )


class TestBuildPayloads:
    def test_single_announcement(self) -> None:
        payloads = _build_payloads([_make_ann("a", "Title")])
        assert len(payloads) == 1
        assert len(payloads[0]["embeds"]) == 1
        assert "Mobility RFP Alert" in payloads[0]["content"]

    def test_batch_split_at_10(self) -> None:
        anns = [_make_ann(f"d-{i}", f"Title {i}") for i in range(15)]
        payloads = _build_payloads(anns)
        assert len(payloads) == 2
        assert len(payloads[0]["embeds"]) == 10
        assert len(payloads[1]["embeds"]) == 5

    def test_embed_fields(self) -> None:
        payloads = _build_payloads([_make_ann("f1", "Test")])
        embed = payloads[0]["embeds"][0]
        assert embed["title"] == "Test"
        assert embed["url"] == "https://example.com/f1"
        field_names = [f["name"] for f in embed["fields"]]
        assert "소스" in field_names
        assert "기관" in field_names
        assert "키워드" in field_names

    def test_empty_list(self) -> None:
        assert _build_payloads([]) == []


class TestDiscordChannel:
    def test_send_success(self) -> None:
        transport = httpx.MockTransport(lambda req: httpx.Response(204))
        with httpx.Client(transport=transport) as client:
            ch = DiscordChannel(client, "https://discord.com/api/webhooks/test")
            assert ch.channel_name == "discord"
            assert ch.send([_make_ann("a", "T")]) == 1

    def test_send_empty(self) -> None:
        transport = httpx.MockTransport(lambda req: httpx.Response(204))
        with httpx.Client(transport=transport) as client:
            ch = DiscordChannel(client, "https://discord.com/api/webhooks/test")
            assert ch.send([]) == 0

    def test_send_http_error(self) -> None:
        transport = httpx.MockTransport(lambda req: httpx.Response(400, text="bad request"))
        with httpx.Client(transport=transport) as client:
            ch = DiscordChannel(client, "https://discord.com/api/webhooks/test")
            with pytest.raises(DiscordNotificationError):
                ch.send([_make_ann("a", "T")])

    def test_large_batch_sends_multiple_requests(self) -> None:
        request_count = []

        def handler(request: httpx.Request) -> httpx.Response:
            request_count.append(1)
            return httpx.Response(204)

        transport = httpx.MockTransport(handler)
        with httpx.Client(transport=transport) as client:
            ch = DiscordChannel(client, "https://discord.com/api/webhooks/test")
            anns = [_make_ann(f"d-{i}", f"Title {i}") for i in range(25)]
            count = ch.send(anns)

        assert count == 25
        assert len(request_count) == 3  # 10 + 10 + 5
