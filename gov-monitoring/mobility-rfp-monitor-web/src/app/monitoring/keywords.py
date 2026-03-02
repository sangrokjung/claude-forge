"""Mobility / MaaS keyword matching.

Keywords are stored in a ``frozenset`` and compiled into a single regex
pattern (longest-first) for efficient matching.

Copied from CLI project (mobility-rfp-monitor).
"""

from __future__ import annotations

import re

MOBILITY_KEYWORDS: frozenset[str] = frozenset(
    {
        # 모빌리티 일반
        "모빌리티",
        "mobility",
        "스마트모빌리티",
        "스마트 모빌리티",
        "마이크로모빌리티",
        "퍼스널모빌리티",
        "도심항공모빌리티",
        "UAM",
        "PAV",
        # MaaS
        "MaaS",
        "maas",
        "통합모빌리티",
        "통합 모빌리티",
        "모빌리티 플랫폼",
        "모빌리티플랫폼",
        "통합교통",
        "통합 교통",
        # 자율주행
        "자율주행",
        "자율 주행",
        "autonomous driving",
        "autonomous vehicle",
        "자율차",
        "자율주행차",
        "레벨4",
        "레벨 4",
        "level 4",
        "레벨5",
        "레벨 5",
        "ADAS",
        # 전기차 / 수소차
        "전기차",
        "전기자동차",
        "EV",
        "수소차",
        "수소전기차",
        "FCEV",
        "충전인프라",
        "충전 인프라",
        "급속충전",
        "완속충전",
        # 커넥티드카
        "커넥티드카",
        "커넥티드 카",
        "connected car",
        "V2X",
        "V2I",
        "V2V",
        "C-ITS",
        "차량통신",
        # 공유/온디맨드
        "차량공유",
        "차량 공유",
        "카셰어링",
        "카쉐어링",
        "car sharing",
        "라이드헤일링",
        "ride hailing",
        "온디맨드",
        "on-demand",
        "DRT",
        "수요응답형",
        "수요 응답형",
        # 킥보드/자전거
        "전동킥보드",
        "전동 킥보드",
        "공유킥보드",
        "공유자전거",
        "공유 자전거",
        "따릉이",
        # ITS / 교통
        "ITS",
        "지능형교통",
        "지능형 교통",
        "교통정보",
        "교통 정보",
        "실시간교통",
        "스마트교통",
        "스마트 교통",
        "교통데이터",
        "교통 데이터",
        # 물류
        "스마트물류",
        "스마트 물류",
        "라스트마일",
        "last mile",
        "자율배송",
        "자율 배송",
        "배송로봇",
        "배송 로봇",
        "드론배송",
        "드론 배송",
        # 플라잉카 / 로보택시
        "플라잉카",
        "flying car",
        "로보택시",
        "robotaxi",
        "에어택시",
        "air taxi",
        # 인프라
        "스마트도로",
        "스마트 도로",
        "스마트시티",
        "스마트 시티",
        "디지털트윈",
        "digital twin",
    }
)

_SORTED_KEYWORDS = sorted(MOBILITY_KEYWORDS, key=len, reverse=True)

_SHORT_ASCII_RE = re.compile(r"^[A-Za-z\-]{1,4}$")

_CASE_SENSITIVE_KEYWORDS: frozenset[str] = frozenset({"ITS"})


def _to_pattern_fragment(kw: str) -> str:
    escaped = re.escape(kw)
    if _SHORT_ASCII_RE.match(kw):
        return rf"\b{escaped}\b"
    return escaped


_normal_keywords = [kw for kw in _SORTED_KEYWORDS if kw not in _CASE_SENSITIVE_KEYWORDS]
_PATTERN: re.Pattern[str] = re.compile(
    "|".join(_to_pattern_fragment(kw) for kw in _normal_keywords),
    re.IGNORECASE,
)

_CASE_SENSITIVE_PATTERN: re.Pattern[str] = re.compile(
    "|".join(rf"\b{re.escape(kw)}\b" for kw in sorted(_CASE_SENSITIVE_KEYWORDS, key=len, reverse=True)),
)


def matches_any_keyword(text: str) -> bool:
    """Return True if text contains at least one mobility keyword."""
    if not text:
        return False
    return _PATTERN.search(text) is not None or _CASE_SENSITIVE_PATTERN.search(text) is not None


def find_matching_keywords(text: str) -> frozenset[str]:
    """Return all mobility keywords found in text (lower-cased originals)."""
    if not text:
        return frozenset()
    found = _PATTERN.findall(text)
    found_cs = _CASE_SENSITIVE_PATTERN.findall(text)
    return frozenset(m.lower() for m in (*found, *found_cs))
