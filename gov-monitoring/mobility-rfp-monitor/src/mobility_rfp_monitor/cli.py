"""CLI entry point — ``python -m mobility_rfp_monitor``."""

from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Sequence

import httpx

from mobility_rfp_monitor.channels.base import NotificationChannel
from mobility_rfp_monitor.channels.discord import DiscordChannel
from mobility_rfp_monitor.channels.slack import SlackChannel
from mobility_rfp_monitor.channels.webhook import WebhookChannel
from mobility_rfp_monitor.client import fetch_g2b_bids, fetch_mss
from mobility_rfp_monitor.config import ChannelsConfig, load_config, channels_from_env
from mobility_rfp_monitor.exceptions import ApiError, ConfigError
from mobility_rfp_monitor.filter import filter_announcements
from mobility_rfp_monitor.models import Announcement, MonitorResult
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
        help="알림 없이 매칭 결과만 출력",
    )
    parser.add_argument(
        "--state-file",
        type=str,
        default=".state.json",
        help="상태 파일 경로 (기본: .state.json)",
    )
    parser.add_argument(
        "--config",
        type=str,
        default=None,
        help="YAML 설정 파일 경로 (미지정 시 환경변수 사용)",
    )
    parser.add_argument(
        "--channels",
        type=str,
        default=None,
        help="활성화할 채널 (쉼표 구분, 예: slack,email,discord,webhook)",
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


def _resolve_channels_config(
    args: argparse.Namespace,
) -> ChannelsConfig | None:
    """Build ChannelsConfig from --config file or environment variables."""
    if args.config:
        try:
            return load_config(Path(args.config))
        except ConfigError as exc:
            print(f"Error: {exc}", file=sys.stderr)
            return None

    return channels_from_env(
        slack_url=os.environ.get("SLACK_WEBHOOK_URL", ""),
        discord_url=os.environ.get("DISCORD_WEBHOOK_URL", ""),
        webhook_url=os.environ.get("WEBHOOK_URL", ""),
    )


def _build_active_channels(
    channels_config: ChannelsConfig,
    http_client: httpx.Client,
    requested: set[str] | None,
) -> list[NotificationChannel]:
    """Instantiate notification channel objects from config."""
    active: list[NotificationChannel] = []

    if channels_config.slack and (requested is None or "slack" in requested):
        active.append(SlackChannel(http_client, channels_config.slack.webhook_url))

    if channels_config.email and (requested is None or "email" in requested):
        from mobility_rfp_monitor.channels.email import EmailChannel

        cfg = channels_config.email
        active.append(
            EmailChannel(
                smtp_host=cfg.smtp_host,
                smtp_port=cfg.smtp_port,
                smtp_user=cfg.smtp_user,
                smtp_password=cfg.smtp_password,
                from_addr=cfg.from_addr,
                to_addrs=list(cfg.to_addrs),
                subject_prefix=cfg.subject_prefix,
                use_starttls=cfg.use_starttls,
                max_items_per_email=cfg.max_items_per_email,
            )
        )

    if channels_config.discord and (requested is None or "discord" in requested):
        active.append(DiscordChannel(http_client, channels_config.discord.webhook_url))

    if channels_config.webhook and (requested is None or "webhook" in requested):
        active.append(
            WebhookChannel(
                http_client,
                channels_config.webhook.url,
                headers=dict(channels_config.webhook.headers),
            )
        )

    return active


def _send_notifications(
    channels: Sequence[NotificationChannel],
    announcements: list[Announcement],
) -> int:
    """Send announcements through all active channels.

    Each channel runs independently — one failure does not block others.
    Returns total notified count (max across channels).
    """
    if not announcements or not channels:
        return 0

    max_notified = 0
    for channel in channels:
        try:
            count = channel.send(announcements)
            max_notified = max(max_notified, count)
            print(f"  [{channel.channel_name}] {count}건 알림 전송 완료")
        except Exception as exc:
            print(f"  [{channel.channel_name}] 알림 실패: {exc}", file=sys.stderr)

    return max_notified


def _validate_env(dry_run: bool, has_config: bool) -> str | None:
    """Return ``service_key`` or ``None`` on validation failure."""
    service_key = os.environ.get("DATA_GO_KR_API_KEY", "")
    if not service_key:
        print("Error: DATA_GO_KR_API_KEY environment variable is not set.", file=sys.stderr)
        return None

    if not dry_run and not has_config:
        webhook_url = os.environ.get("SLACK_WEBHOOK_URL", "")
        discord_url = os.environ.get("DISCORD_WEBHOOK_URL", "")
        webhook_generic = os.environ.get("WEBHOOK_URL", "")
        if not any([webhook_url, discord_url, webhook_generic]):
            print(
                "Error: No notification channel configured. "
                "Set SLACK_WEBHOOK_URL, DISCORD_WEBHOOK_URL, or WEBHOOK_URL. "
                "Use --dry-run to skip or --config for YAML config.",
                file=sys.stderr,
            )
            return None

    return service_key


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

    has_config = args.config is not None
    service_key = _validate_env(args.dry_run, has_config)
    if service_key is None:
        return 1

    channels_config = _resolve_channels_config(args)
    if channels_config is None:
        return 1

    requested_channels: set[str] | None = None
    if args.channels:
        requested_channels = {ch.strip() for ch in args.channels.split(",")}

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
            active_channels = _build_active_channels(channels_config, client, requested_channels)
            notified = _send_notifications(active_channels, new_items)
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
