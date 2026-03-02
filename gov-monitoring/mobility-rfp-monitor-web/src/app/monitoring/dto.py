"""Normalized notice DTO shared across all sources."""

from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True, slots=True)
class NormalizedNotice:
    source: str
    source_item_id: str
    title: str
    agency: str
    summary: str
    url: str
    deadline: str
    published_at: str
    fetched_at: str
    matched_keywords: frozenset[str] = frozenset()
    raw: dict = field(default_factory=dict)

    @property
    def source_item_uid(self) -> str:
        return f"{self.source}:{self.source_item_id}"
