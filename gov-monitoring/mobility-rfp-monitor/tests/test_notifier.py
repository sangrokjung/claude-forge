"""Tests for notifier.py — Slack Block Kit formatting and webhook call."""

from __future__ import annotations

import json

import httpx
import pytest

from mobility_rfp_monitor.exceptions import SlackNotificationError
from mobility_rfp_monitor.models import Announcement, AnnouncementSource
from mobility_rfp_monitor.notifier import format_slack_message, send_slack_notification


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

    def test_contains_title_link(self) -> None:
        anns = [_make_ann("a", "모빌리티 실증")]
        payload = format_slack_message(anns)
        section = payload["blocks"][1]
        assert "모빌리티 실증" in section["text"]["text"]
        assert "https://example.com/a" in section["text"]["text"]


class TestSendSlackNotification:
    def test_success(self) -> None:
        transport = httpx.MockTransport(lambda req: httpx.Response(200, text="ok"))
        with httpx.Client(transport=transport) as client:
            count = send_slack_notification(client, "https://hooks.slack.com/test", [_make_ann("a", "T")])
        assert count == 1

    def test_empty_list(self) -> None:
        transport = httpx.MockTransport(lambda req: httpx.Response(200, text="ok"))
        with httpx.Client(transport=transport) as client:
            count = send_slack_notification(client, "https://hooks.slack.com/test", [])
        assert count == 0

    def test_http_error(self) -> None:
        transport = httpx.MockTransport(lambda req: httpx.Response(500, text="error"))
        with httpx.Client(transport=transport) as client:
            with pytest.raises(SlackNotificationError) as exc_info:
                send_slack_notification(client, "https://hooks.slack.com/test", [_make_ann("a", "T")])
        assert exc_info.value.status_code == 500


# ── TDD Cycle 3: Block Kit 구조 심층 검증 ──────────────────────────


class TestBlockKitStructure:
    """Slack Block Kit 스펙에 맞는 구조인지 상세 검증."""

    def test_header_is_plain_text(self) -> None:
        payload = format_slack_message([_make_ann("a", "T")])
        header = payload["blocks"][0]
        assert header["type"] == "header"
        assert header["text"]["type"] == "plain_text"

    def test_each_announcement_has_section_then_divider(self) -> None:
        """각 공고는 section + divider 쌍으로 표현."""
        payload = format_slack_message([_make_ann("a", "T"), _make_ann("b", "T2")])
        blocks = payload["blocks"]
        # blocks[0] = header, blocks[1] = section, blocks[2] = divider, blocks[3] = section, blocks[4] = divider
        assert blocks[1]["type"] == "section"
        assert blocks[2]["type"] == "divider"
        assert blocks[3]["type"] == "section"
        assert blocks[4]["type"] == "divider"

    def test_section_text_is_mrkdwn(self) -> None:
        payload = format_slack_message([_make_ann("a", "T")])
        section = payload["blocks"][1]
        assert section["text"]["type"] == "mrkdwn"

    def test_total_block_count(self) -> None:
        """n개 공고 → 1(header) + n*2(section+divider) 블록."""
        payload = format_slack_message([_make_ann("a", "A"), _make_ann("b", "B"), _make_ann("c", "C")])
        assert len(payload["blocks"]) == 1 + 3 * 2


class TestNoUrlAnnouncement:
    """URL이 없는 공고는 링크 없이 bold 제목만 표시."""

    def test_no_url_shows_bold_title(self) -> None:
        ann = _make_ann("nurl", "제목만 표시", url="")
        payload = format_slack_message([ann])
        section_text = payload["blocks"][1]["text"]["text"]
        assert "*제목만 표시*" in section_text
        assert "<" not in section_text  # Slack 링크 문법 없어야 함

    def test_with_url_shows_link(self) -> None:
        ann = _make_ann("wurl", "링크 있는 공고")
        payload = format_slack_message([ann])
        section_text = payload["blocks"][1]["text"]["text"]
        assert "<https://example.com/wurl|링크 있는 공고>" in section_text


class TestSourceLabels:
    """모든 AnnouncementSource에 대해 올바른 한글 라벨이 표시."""

    def test_mss_label(self) -> None:
        ann = _make_ann("s1", "T", source=AnnouncementSource.MSS)
        payload = format_slack_message([ann])
        text = payload["blocks"][1]["text"]["text"]
        assert "중기부 기술개발" in text

    def test_g2b_bid_label(self) -> None:
        ann = _make_ann("s2", "T", source=AnnouncementSource.G2B_BID)
        payload = format_slack_message([ann])
        text = payload["blocks"][1]["text"]["text"]
        assert "나라장터 입찰" in text


class TestKeywordsInPayload:
    """matched_keywords가 payload에 backtick으로 표시."""

    def test_keywords_sorted_in_payload(self) -> None:
        ann = _make_ann("k1", "T", keywords=frozenset({"전기차", "모빌리티", "자율주행"}))
        payload = format_slack_message([ann])
        text = payload["blocks"][1]["text"]["text"]
        assert "`모빌리티, 자율주행, 전기차`" in text

    def test_empty_keywords_shows_dash(self) -> None:
        ann = _make_ann("k2", "T", keywords=frozenset())
        payload = format_slack_message([ann])
        text = payload["blocks"][1]["text"]["text"]
        assert "`-`" in text


class TestSendSlackPayloadContent:
    """실제 전송되는 JSON payload의 구조를 mock에서 캡처해 검증."""

    def test_payload_has_blocks_key(self) -> None:
        captured: list[bytes] = []

        def handler(request: httpx.Request) -> httpx.Response:
            captured.append(request.content)
            return httpx.Response(200, text="ok")

        transport = httpx.MockTransport(handler)
        with httpx.Client(transport=transport) as client:
            send_slack_notification(
                client, "https://hooks.slack.com/test", [_make_ann("p1", "Payload Test")]
            )

        assert len(captured) == 1
        body = json.loads(captured[0])
        assert "blocks" in body
        assert body["blocks"][0]["type"] == "header"

    def test_webhook_url_is_posted_to(self) -> None:
        """POST 요청이 정확한 webhook URL로 전송되는지."""
        posted_urls: list[str] = []

        def handler(request: httpx.Request) -> httpx.Response:
            posted_urls.append(str(request.url))
            return httpx.Response(200, text="ok")

        transport = httpx.MockTransport(handler)
        with httpx.Client(transport=transport) as client:
            send_slack_notification(
                client, "https://hooks.slack.com/services/T/B/X", [_make_ann("u1", "URL Test")]
            )

        assert posted_urls == ["https://hooks.slack.com/services/T/B/X"]


class TestFormatEmptyList:
    """빈 리스트로 format_slack_message 호출 시 0건 헤더만."""

    def test_empty_announcements(self) -> None:
        payload = format_slack_message([])
        assert len(payload["blocks"]) == 1
        assert "0건" in payload["blocks"][0]["text"]["text"]


class TestSlackBlockLimit:
    """Slack Block Kit은 50블록 제한. 대량 공고 시 초과하면 안 된다."""

    SLACK_MAX_BLOCKS = 50

    def _make_many(self, n: int) -> list[Announcement]:
        return [
            Announcement(
                id=f"bulk-{i}",
                source=AnnouncementSource.MSS,
                title=f"공고 {i}",
                description="",
                url="",
                published_at="",
                organization="",
                matched_keywords=frozenset({"모빌리티"}),
            )
            for i in range(n)
        ]

    def test_30_announcements_under_limit(self) -> None:
        """30개 공고도 50블록 이하여야 한다."""
        payload = format_slack_message(self._make_many(30))
        assert len(payload["blocks"]) <= self.SLACK_MAX_BLOCKS

    def test_50_announcements_under_limit(self) -> None:
        payload = format_slack_message(self._make_many(50))
        assert len(payload["blocks"]) <= self.SLACK_MAX_BLOCKS

    def test_truncated_message_includes_count(self) -> None:
        """블록 제한으로 잘릴 때, 몇 건 중 몇 건만 표시했는지 알려줘야 한다."""
        payload = format_slack_message(self._make_many(30))
        header_text = payload["blocks"][0]["text"]["text"]
        assert "30건" in header_text


# ── TDD Cycle 6: 잘림 안내 + 소스 혼합 payload ──────────────────


class TestTruncationFooter:
    """대량 공고 시 잘림 안내 footer가 있어야 한다."""

    def _make_many(self, n: int) -> list[Announcement]:
        return [
            Announcement(
                id=f"tf-{i}",
                source=AnnouncementSource.MSS,
                title=f"공고 {i}",
                description="",
                url="",
                published_at="",
                organization="",
                matched_keywords=frozenset({"모빌리티"}),
            )
            for i in range(n)
        ]

    def test_truncated_has_footer_context(self) -> None:
        """50개 공고 → 블록 잘림 시 마지막 블록에 '... 외 N건' 안내."""
        payload = format_slack_message(self._make_many(50))
        blocks = payload["blocks"]
        last_block_text = blocks[-1].get("text", {}).get("text", "")
        # 마지막 블록이 context/section으로 잘림 안내를 포함해야 함
        assert "외" in last_block_text or "more" in last_block_text.lower()

    def test_small_list_no_footer(self) -> None:
        """5개 공고 → 잘림 없으므로 footer 없음. 마지막은 divider."""
        payload = format_slack_message(self._make_many(5))
        blocks = payload["blocks"]
        assert blocks[-1]["type"] == "divider"


class TestMixedSourcePayload:
    """MSS + G2B_BID 혼합 공고의 Slack payload."""

    def test_mixed_sources_have_correct_labels(self) -> None:
        anns = [
            Announcement(
                id="mix-mss",
                source=AnnouncementSource.MSS,
                title="중기부 공고",
                description="",
                url="",
                published_at="2026-03-01",
                organization="진흥원",
                matched_keywords=frozenset({"모빌리티"}),
            ),
            Announcement(
                id="mix-g2b",
                source=AnnouncementSource.G2B_BID,
                title="나라장터 입찰",
                description="",
                url="https://g2b.go.kr/bid/1",
                published_at="2026-03-01",
                organization="서울시",
                matched_keywords=frozenset({"전기차"}),
            ),
        ]
        payload = format_slack_message(anns)
        mss_text = payload["blocks"][1]["text"]["text"]
        g2b_text = payload["blocks"][3]["text"]["text"]
        assert "중기부 기술개발" in mss_text
        assert "나라장터 입찰" in g2b_text

    def test_g2b_with_url_shows_link(self) -> None:
        ann = Announcement(
            id="g2b-link",
            source=AnnouncementSource.G2B_BID,
            title="전기차 충전소 구축",
            description="",
            url="https://g2b.go.kr/bid/123",
            published_at="2026-03-01",
            organization="한전",
            matched_keywords=frozenset({"전기차"}),
        )
        payload = format_slack_message([ann])
        text = payload["blocks"][1]["text"]["text"]
        assert "<https://g2b.go.kr/bid/123|전기차 충전소 구축>" in text
