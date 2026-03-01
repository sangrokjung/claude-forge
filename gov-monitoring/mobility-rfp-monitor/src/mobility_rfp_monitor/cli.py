"""CLI entry point — ``python -m mobility_rfp_monitor``."""

from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import httpx

from mobility_rfp_monitor.client import fetch_g2b_bids, fetch_mss
from mobility_rfp_monitor.exceptions import ApiError
from mobility_rfp_monitor.filter import filter_announcements
from mobility_rfp_monitor.models import Announcement, MonitorResult
from mobility_rfp_monitor.notifier import send_slack_notification
from mobility_rfp_monitor.state import State, filter_unseen, load_state, prune_state, save_state


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="mobility-rfp-monitor",
        description="중기부/나라장터 모빌리티 공고 모니터링",
    )
    parser.add_argument(
        "--since-hours",
        type=int,
        default=24,
        help="조회 범위 (시간, 기본: 24)",
    )
    parser.add_argument(
        "--source",
        choices=["mss", "g2b", "all"],
        default="all",
        help="조회 소스 (기본: all)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Slack 알림 없이 매칭 결과만 출력",
    )
    parser.add_argument(
        "--state-file",
        type=str,
        default=".state.json",
        help="상태 파일 경로 (기본: .state.json)",
    )
    return parser


def _print_results(items: list[Announcement]) -> None:
    if not items:
        print("No matching announcements found.")
        return
    print(f"\n{'='*60}")
    print(f" Found {len(items)} matching announcement(s)")
    print(f"{'='*60}\n")
    for ann in items:
        keywords = ", ".join(sorted(ann.matched_keywords)) if ann.matched_keywords else "-"
        print(f"  [{ann.source.value}] {ann.title}")
        if ann.description:
            print(f"  Description: {ann.description[:80]}")
        print(f"  Organization: {ann.organization}")
        print(f"  Published: {ann.published_at}")
        print(f"  Keywords: {keywords}")
        if ann.url:
            print(f"  URL: {ann.url}")
        print()


def _fetch_all(
    http_client: httpx.Client,
    service_key: str,
    source: str,
    since: datetime,
    until: datetime,
) -> list[Announcement]:
    results: list[Announcement] = []
    since_str = since.strftime("%Y%m%d%H%M")
    until_str = until.strftime("%Y%m%d%H%M")

    if source in ("mss", "all"):
        try:
            results.extend(fetch_mss(http_client, service_key))
        except (ApiError, httpx.HTTPError) as exc:
            print(f"[WARN] MSS fetch failed: {exc}", file=sys.stderr)

    if source in ("g2b", "all"):
        try:
            results.extend(
                fetch_g2b_bids(http_client, service_key, since=since_str, until=until_str)
            )
        except (ApiError, httpx.HTTPError) as exc:
            print(f"[WARN] G2B bids fetch failed: {exc}", file=sys.stderr)

    return results


def _validate_env(dry_run: bool) -> tuple[str, str] | None:
    """Return ``(service_key, webhook_url)`` or ``None`` on validation failure."""
    service_key = os.environ.get("DATA_GO_KR_API_KEY", "")
    if not service_key:
        print("Error: DATA_GO_KR_API_KEY environment variable is not set.", file=sys.stderr)
        return None

    webhook_url = os.environ.get("SLACK_WEBHOOK_URL", "")
    if not dry_run and not webhook_url:
        print("Error: SLACK_WEBHOOK_URL environment variable is not set. Use --dry-run to skip.", file=sys.stderr)
        return None

    return service_key, webhook_url


def _print_summary(result: MonitorResult) -> None:
    print(
        f"\nSummary: {result.total_fetched} fetched"
        f" -> {result.keyword_matched} matched"
        f" -> {result.new_items} new"
        f" -> {result.notified} notified"
    )


def main(
    argv: list[str] | None = None,
    *,
    http_client: httpx.Client | None = None,
) -> int:
    """CLI entry point.  Returns exit code.

    An optional *http_client* can be injected for testing.
    """
    args = _build_parser().parse_args(argv)

    env = _validate_env(args.dry_run)
    if env is None:
        return 1
    service_key, webhook_url = env

    now = datetime.now(timezone.utc)
    since = now - timedelta(hours=args.since_hours)
    state_path = Path(args.state_file)
    state = load_state(state_path)

    def _run(client: httpx.Client) -> tuple[list[Announcement], list[Announcement], list[Announcement], int, State]:
        all_anns = _fetch_all(client, service_key, args.source, since, now)
        filtered = filter_announcements(all_anns)
        new_items, updated = filter_unseen(filtered, state)
        notified = 0
        if not args.dry_run and new_items:
            notified = send_slack_notification(client, webhook_url, new_items)
        return all_anns, filtered, new_items, notified, updated

    if http_client is not None:
        all_anns, filtered, new_items, notified, updated_state = _run(http_client)
    else:
        with httpx.Client(timeout=30.0) as managed_client:
            all_anns, filtered, new_items, notified, updated_state = _run(managed_client)

    _print_results(new_items)
    save_state(prune_state(updated_state), state_path)
    _print_summary(MonitorResult(
        total_fetched=len(all_anns),
        keyword_matched=len(filtered),
        new_items=len(new_items),
        notified=notified,
    ))
    return 0
