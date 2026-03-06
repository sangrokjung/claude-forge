"""Keyword filter orchestrator.

Scans announcement title + description against the mobility keyword set
and attaches matched keywords to each passing announcement.
"""

from __future__ import annotations

from mobility_rfp_monitor.keywords import find_matching_keywords
from mobility_rfp_monitor.models import Announcement


def filter_announcements(
    announcements: list[Announcement],
) -> list[Announcement]:
    """Return announcements that match at least one mobility keyword.

    Each returned ``Announcement`` has its ``matched_keywords`` populated.
    The original list and its items are **not** mutated.
    """
    results: list[Announcement] = []
    for ann in announcements:
        text = f"{ann.title} {ann.description}"
        matched = find_matching_keywords(text)
        if matched:
            results.append(
                Announcement(
                    id=ann.id,
                    source=ann.source,
                    title=ann.title,
                    description=ann.description,
                    url=ann.url,
                    published_at=ann.published_at,
                    organization=ann.organization,
                    matched_keywords=matched,
                )
            )
    return results
