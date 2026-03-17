"""Phase 5: Keyword filter tests."""

from __future__ import annotations

from app.monitoring.dto import NormalizedNotice
from app.monitoring.filter import filter_notices


def _make_notice(title: str, summary: str = "") -> NormalizedNotice:
    return NormalizedNotice(
        source="test",
        source_item_id="1",
        title=title,
        agency="TestOrg",
        summary=summary,
        url="",
        deadline="",
        published_at="2026-01-01",
        fetched_at="2026-03-02T00:00:00",
    )


def test_filter_matches_mobility_keyword():
    notices = [_make_notice("자율주행 기술개발 사업")]
    result = filter_notices(notices)
    assert len(result) == 1
    assert "자율주행" in result[0].matched_keywords


def test_filter_excludes_no_match():
    notices = [_make_notice("사무용품 구매 공고")]
    result = filter_notices(notices)
    assert len(result) == 0


def test_filter_matches_english_keyword():
    notices = [_make_notice("autonomous driving platform")]
    result = filter_notices(notices)
    assert len(result) == 1


def test_filter_matches_in_summary():
    notices = [_make_notice("일반 사업 공고", summary="전기차 충전인프라 개발")]
    result = filter_notices(notices)
    assert len(result) == 1
    assert "전기차" in result[0].matched_keywords or "충전인프라" in result[0].matched_keywords


def test_filter_does_not_mutate_input():
    original = _make_notice("자율주행 테스트")
    notices = [original]
    result = filter_notices(notices)
    assert original.matched_keywords == frozenset()
    assert len(result[0].matched_keywords) > 0
