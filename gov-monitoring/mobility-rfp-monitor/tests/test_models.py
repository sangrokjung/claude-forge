"""Tests for models.py — immutability and data integrity."""

from __future__ import annotations

import pytest

from mobility_rfp_monitor.models import Announcement, AnnouncementSource, MonitorResult


class TestAnnouncementSource:
    def test_values(self) -> None:
        assert AnnouncementSource.MSS.value == "mss"
        assert AnnouncementSource.G2B_BID.value == "g2b_bid"


class TestAnnouncement:
    def test_frozen(self) -> None:
        ann = Announcement(
            id="test-1",
            source=AnnouncementSource.MSS,
            title="Test",
            description="Desc",
            url="",
            published_at="2026-01-01",
            organization="Org",
        )
        with pytest.raises(AttributeError):
            ann.title = "Mutated"  # type: ignore[misc]

    def test_default_keywords(self) -> None:
        ann = Announcement(
            id="test-1",
            source=AnnouncementSource.MSS,
            title="Test",
            description="Desc",
            url="",
            published_at="2026-01-01",
            organization="Org",
        )
        assert ann.matched_keywords == frozenset()

    def test_with_keywords(self) -> None:
        ann = Announcement(
            id="test-1",
            source=AnnouncementSource.G2B_BID,
            title="Test",
            description="Desc",
            url="",
            published_at="2026-01-01",
            organization="Org",
            matched_keywords=frozenset({"자율주행", "모빌리티"}),
        )
        assert "자율주행" in ann.matched_keywords
        assert len(ann.matched_keywords) == 2

    def test_equality(self) -> None:
        kwargs = dict(
            id="test-1",
            source=AnnouncementSource.MSS,
            title="T",
            description="D",
            url="",
            published_at="2026-01-01",
            organization="O",
        )
        assert Announcement(**kwargs) == Announcement(**kwargs)


class TestMonitorResult:
    def test_frozen(self) -> None:
        result = MonitorResult(total_fetched=10, keyword_matched=5, new_items=3, notified=3)
        with pytest.raises(AttributeError):
            result.notified = 0  # type: ignore[misc]
        assert result.total_fetched == 10
