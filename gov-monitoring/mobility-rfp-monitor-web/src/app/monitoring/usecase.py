"""Monitoring orchestrator: fetch → filter → dedupe → notify."""

from __future__ import annotations

import logging
from dataclasses import dataclass

import httpx
from sqlalchemy.orm import Session

from app.monitoring.dedupe import filter_unseen
from app.monitoring.dto import NormalizedNotice
from app.monitoring.filter import filter_notices
from app.monitoring.sources.base import SourceConfig
from app.monitoring.sources.generic_client import GenericSourceClient

logger = logging.getLogger(__name__)


@dataclass(frozen=True, slots=True)
class RunResult:
    total_fetched: int
    keyword_matched: int
    new_items: int
    notices: list[NormalizedNotice]
    errors: list[str]


def run_monitoring_for_user(
    *,
    user_id: int,
    source_configs: list[SourceConfig],
    since_hours: int,
    session: Session,
    http_client: httpx.Client | None = None,
) -> RunResult:
    """Fetch from all sources, filter by keywords, deduplicate, return results."""
    client = http_client or httpx.Client(timeout=20.0)
    all_notices: list[NormalizedNotice] = []
    errors: list[str] = []

    for config in source_configs:
        try:
            source_client = GenericSourceClient(config, client)
            notices = source_client.fetch(since_hours=since_hours)
            all_notices.extend(notices)
        except Exception as exc:
            logger.warning("Source %s failed: %s", config.name, exc)
            errors.append(f"{config.name}: {exc}")

    total_fetched = len(all_notices)

    matched = filter_notices(all_notices)
    keyword_matched = len(matched)

    new_notices = filter_unseen(user_id, matched, session)

    return RunResult(
        total_fetched=total_fetched,
        keyword_matched=keyword_matched,
        new_items=len(new_notices),
        notices=new_notices,
        errors=errors,
    )
