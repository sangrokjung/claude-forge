"""Tests for keywords.py — keyword matching and frozenset integrity."""

from __future__ import annotations

from mobility_rfp_monitor.keywords import (
    MOBILITY_KEYWORDS,
    find_matching_keywords,
    matches_any_keyword,
)


class TestMobilityKeywords:
    def test_is_frozenset(self) -> None:
        assert isinstance(MOBILITY_KEYWORDS, frozenset)
        assert len(MOBILITY_KEYWORDS) >= 60

    def test_contains_core_keywords(self) -> None:
        assert "모빌리티" in MOBILITY_KEYWORDS
        assert "자율주행" in MOBILITY_KEYWORDS
        assert "MaaS" in MOBILITY_KEYWORDS
        assert "전기차" in MOBILITY_KEYWORDS


class TestMatchesAnyKeyword:
    def test_korean_keyword(self) -> None:
        assert matches_any_keyword("자율주행 실증사업 공고") is True

    def test_english_keyword(self) -> None:
        assert matches_any_keyword("UAM pilot project") is True

    def test_case_insensitive(self) -> None:
        assert matches_any_keyword("maas platform") is True
        assert matches_any_keyword("MAAS PLATFORM") is True

    def test_no_match(self) -> None:
        assert matches_any_keyword("사무용품 구매") is False

    def test_empty_string(self) -> None:
        assert matches_any_keyword("") is False

    def test_keyword_in_longer_text(self) -> None:
        text = "정부가 2026년 스마트도로 인프라 구축을 위한 예산을 편성했다."
        assert matches_any_keyword(text) is True


class TestFindMatchingKeywords:
    def test_multiple_keywords(self) -> None:
        text = "자율주행 전기차 충전인프라 구축사업"
        found = find_matching_keywords(text)
        assert "자율주행" in found
        assert "전기차" in found
        assert "충전인프라" in found

    def test_returns_frozenset(self) -> None:
        result = find_matching_keywords("모빌리티 플랫폼")
        assert isinstance(result, frozenset)

    def test_empty_string(self) -> None:
        assert find_matching_keywords("") == frozenset()

    def test_no_match(self) -> None:
        assert find_matching_keywords("사무용품 구매") == frozenset()

    def test_lowercased(self) -> None:
        found = find_matching_keywords("UAM pilot")
        assert "uam" in found


# ── TDD Cycle 1: 영문 짧은 키워드 false positive 방지 ─────────────


class TestShortKeywordFalsePositive:
    """EV, ITS 같은 2~3글자 영문 키워드가 일반 단어 안에서 오탐하면 안 된다."""

    def test_ev_not_in_never(self) -> None:
        assert find_matching_keywords("NEVER") == frozenset()

    def test_ev_not_in_every(self) -> None:
        assert find_matching_keywords("EVERY") == frozenset()

    def test_ev_not_in_prevention(self) -> None:
        assert find_matching_keywords("PREVENTION") == frozenset()

    def test_its_not_in_its_own(self) -> None:
        """영어 소유격 'its'에 매칭하면 안 된다."""
        assert find_matching_keywords("its own problem") == frozenset()

    def test_ev_standalone_matches(self) -> None:
        """'EV' 단독이나 'EV 충전' 같은 문맥에서는 매칭해야 한다."""
        assert "ev" in find_matching_keywords("EV 충전소")

    def test_its_standalone_matches(self) -> None:
        """'ITS 시스템' 같은 문맥에서는 매칭해야 한다."""
        assert "its" in find_matching_keywords("ITS 시스템 구축")

    def test_ev_matches_with_space_after(self) -> None:
        assert "ev" in find_matching_keywords("EV charging station")

    def test_drt_not_in_dirt(self) -> None:
        assert find_matching_keywords("DIRT road") == frozenset()

    def test_pav_not_in_pavilion(self) -> None:
        assert find_matching_keywords("PAVILION center") == frozenset()
