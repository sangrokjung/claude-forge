"""Tests for filter.py — keyword filter orchestrator."""

from __future__ import annotations

import pytest

from mobility_rfp_monitor.filter import filter_announcements
from mobility_rfp_monitor.models import Announcement, AnnouncementSource


def _ann(
    id_: str,
    title: str = "",
    description: str = "",
    source: AnnouncementSource = AnnouncementSource.MSS,
) -> Announcement:
    return Announcement(
        id=id_,
        source=source,
        title=title,
        description=description,
        url="",
        published_at="2026-03-01",
        organization="Org",
    )


def test_matching_announcements() -> None:
    anns = [
        Announcement(
            id="a",
            source=AnnouncementSource.MSS,
            title="자율주행 모빌리티 실증",
            description="전기차 충전인프라 구축",
            url="",
            published_at="2026-03-01",
            organization="Org",
        ),
    ]
    result = filter_announcements(anns)
    assert len(result) == 1
    assert result[0].matched_keywords
    assert "자율주행" in result[0].matched_keywords


def test_no_match() -> None:
    anns = [
        Announcement(
            id="b",
            source=AnnouncementSource.MSS,
            title="사무용품 구매",
            description="복사 용지 및 토너",
            url="",
            published_at="2026-03-01",
            organization="Org",
        ),
    ]
    result = filter_announcements(anns)
    assert result == []


def test_original_not_mutated() -> None:
    ann = Announcement(
        id="c",
        source=AnnouncementSource.G2B_BID,
        title="전기차 충전소 설치",
        description="급속충전기",
        url="",
        published_at="2026-03-01",
        organization="Org",
    )
    original_keywords = ann.matched_keywords
    filter_announcements([ann])
    assert ann.matched_keywords is original_keywords


def test_empty_list() -> None:
    assert filter_announcements([]) == []


def test_multiple_mixed() -> None:
    anns = [
        Announcement(
            id="m1",
            source=AnnouncementSource.MSS,
            title="MaaS 통합 플랫폼",
            description="",
            url="",
            published_at="",
            organization="",
        ),
        Announcement(
            id="m2",
            source=AnnouncementSource.G2B_BID,
            title="청소용역",
            description="건물 청소",
            url="",
            published_at="",
            organization="",
        ),
        Announcement(
            id="m3",
            source=AnnouncementSource.G2B_BID,
            title="스마트시티 교통 시스템",
            description="V2X 통신",
            url="",
            published_at="",
            organization="",
        ),
    ]
    result = filter_announcements(anns)
    assert len(result) == 2
    ids = {a.id for a in result}
    assert ids == {"m1", "m3"}


# ── TDD Cycle 1: 필터 엣지케이스 ──────────────────────────────────


class TestFilterDescriptionOnly:
    """키워드가 description에만 있을 때도 매칭해야 한다."""

    def test_keyword_only_in_description(self) -> None:
        ann = _ann("d1", title="일반 공고 안내", description="자율주행 서비스 구축")
        result = filter_announcements([ann])
        assert len(result) == 1
        assert "자율주행" in result[0].matched_keywords

    def test_keyword_only_in_title(self) -> None:
        ann = _ann("d2", title="전기차 충전소 설치", description="서울시 관내 설비")
        result = filter_announcements([ann])
        assert len(result) == 1
        assert "전기차" in result[0].matched_keywords


class TestFilterLongestFirst:
    """'스마트 모빌리티'가 '모빌리티'보다 먼저 매칭되어야 한다."""

    def test_longer_keyword_preferred(self) -> None:
        """스마트 모빌리티 텍스트에서 '스마트 모빌리티'가 매칭되어야 한다."""
        ann = _ann("lf1", title="스마트 모빌리티 실증사업")
        result = filter_announcements([ann])
        assert len(result) == 1
        assert "스마트 모빌리티" in result[0].matched_keywords


class TestFilterPreservesOrder:
    """필터 결과 순서가 입력 순서와 동일해야 한다."""

    def test_order_preserved(self) -> None:
        anns = [
            _ann("o1", title="자율주행 1"),
            _ann("o2", title="사무용품"),
            _ann("o3", title="전기차 2"),
        ]
        result = filter_announcements(anns)
        assert [a.id for a in result] == ["o1", "o3"]


class TestFilterReturnIsNewList:
    """반환 리스트가 원본 리스트와 다른 객체여야 한다."""

    def test_returns_new_list_object(self) -> None:
        anns = [_ann("nl1", title="모빌리티 플랫폼")]
        result = filter_announcements(anns)
        assert result is not anns

    def test_returned_announcement_has_keywords_populated(self) -> None:
        ann = _ann("nl2", title="UAM 에어택시 로보택시")
        result = filter_announcements([ann])
        assert len(result) == 1
        assert len(result[0].matched_keywords) >= 3


class TestFilterIdempotent:
    """이미 matched_keywords가 있는 Announcement를 다시 필터링해도 정상 동작."""

    def test_re_filter_with_existing_keywords(self) -> None:
        ann = Announcement(
            id="idem1",
            source=AnnouncementSource.MSS,
            title="전기차 충전인프라",
            description="급속충전",
            url="",
            published_at="",
            organization="",
            matched_keywords=frozenset({"old-keyword"}),
        )
        result = filter_announcements([ann])
        assert len(result) == 1
        # 새로 매칭된 키워드로 대체되어야 하며, old-keyword는 없어야 함
        assert "old-keyword" not in result[0].matched_keywords
        assert "전기차" in result[0].matched_keywords


class TestFilterSpecialCharInText:
    """제목/설명에 특수문자, 괄호, 숫자가 섞여 있을 때."""

    def test_keyword_with_surrounding_parens(self) -> None:
        ann = _ann("sp1", title="(자율주행) 실증사업 공고")
        result = filter_announcements([ann])
        assert len(result) == 1

    def test_keyword_with_numbers(self) -> None:
        ann = _ann("sp2", title="2026년 레벨4 자율주행")
        result = filter_announcements([ann])
        assert len(result) == 1
        assert "레벨4" in result[0].matched_keywords or "레벨 4" in result[0].matched_keywords

    def test_hyphenated_keyword(self) -> None:
        """C-ITS, on-demand 같은 하이픈 포함 키워드."""
        ann = _ann("sp3", title="C-ITS 기반 교통관리")
        result = filter_announcements([ann])
        assert len(result) == 1
        assert "c-its" in result[0].matched_keywords


# ── TDD Cycle 4: 실제 API 데이터 패턴 ────────────────────────────


class TestFilterRealMssPatterns:
    """dry-run에서 발견된 실제 MSS 데이터 패턴 검증."""

    def test_keyword_only_in_description_field_mss(self) -> None:
        """공고명에는 없고 과제명(description)에만 키워드가 있는 패턴.
        MSS API에서 '스마트 제조혁신' 공고의 과제명에 '디지털트윈'이 있는 경우."""
        ann = _ann(
            "mss-dt-1",
            title="2024년도 스마트 제조혁신 기술개발사업 시행계획 공고",
            description="디지털트윈 기반의 공정관리 기능을 갖춘 시스템 개발",
        )
        result = filter_announcements([ann])
        assert len(result) == 1
        assert "디지털트윈" in result[0].matched_keywords

    def test_same_title_different_description_all_match(self) -> None:
        """동일 공고명에 다른 과제명이 여러 개인 패턴 — 각각 독립 매칭."""
        anns = [
            _ann("mss-a", title="제조혁신 공고", description="디지털트윈 공정관리"),
            _ann("mss-b", title="제조혁신 공고", description="자율주행 로봇 배송"),
            _ann("mss-c", title="제조혁신 공고", description="일반 회계시스템"),
        ]
        result = filter_announcements(anns)
        assert len(result) == 2
        assert {r.id for r in result} == {"mss-a", "mss-b"}

    def test_no_false_positive_on_generic_rnd(self) -> None:
        """'기술개발', '시행계획', 'R&D' 같은 범용 단어에 오탐하면 안 됨."""
        ann = _ann(
            "mss-generic",
            title="2024년도 기술개발사업 시행계획 공고",
            description="바이오 의약품 품질관리 기술",
        )
        result = filter_announcements([ann])
        assert result == []

    def test_mixed_korean_english_keyword_in_description(self) -> None:
        """과제명에 한영 혼합 키워드: 'EV 급속충전 시스템'."""
        ann = _ann(
            "mss-ev",
            title="전기차 충전인프라 기술개발 공고",
            description="EV 급속충전 시스템 개발",
        )
        result = filter_announcements([ann])
        assert len(result) == 1
        assert "전기차" in result[0].matched_keywords
        assert "ev" in result[0].matched_keywords
        assert "급속충전" in result[0].matched_keywords
