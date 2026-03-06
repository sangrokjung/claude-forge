"""Keyword filter for NormalizedNotice objects."""

from __future__ import annotations

from dataclasses import replace

from app.monitoring.dto import NormalizedNotice
from app.monitoring.keywords import find_matching_keywords


def filter_notices(notices: list[NormalizedNotice]) -> list[NormalizedNotice]:
    """Return notices matching at least one mobility keyword.

    Each returned notice has matched_keywords populated.
    Input list is NOT mutated.
    """
    results: list[NormalizedNotice] = []
    for notice in notices:
        text = f"{notice.title} {notice.summary} {notice.agency}"
        matched = find_matching_keywords(text)
        if matched:
            results.append(replace(notice, matched_keywords=matched))
    return results
