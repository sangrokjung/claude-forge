"""Domain models — Announcement, AnnouncementSource, MonitorResult."""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class AnnouncementSource(Enum):
    """Origin API of an announcement."""

    MSS = "mss"  # 중소벤처기업부 기술개발과제 (odcloud)
    G2B_BID = "g2b_bid"  # 나라장터 입찰공고


@dataclass(frozen=True, slots=True)
class Announcement:
    """Normalised announcement from any source."""

    id: str
    source: AnnouncementSource
    title: str
    description: str
    url: str
    published_at: str
    organization: str
    matched_keywords: frozenset[str] = frozenset()


@dataclass(frozen=True, slots=True)
class MonitorResult:
    """Aggregated result of a single monitor run."""

    total_fetched: int
    keyword_matched: int
    new_items: int
    notified: int
