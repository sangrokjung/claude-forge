"""YAML configuration loader with environment variable fallback."""

from __future__ import annotations

import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

import yaml

from mobility_rfp_monitor.exceptions import ConfigError


@dataclass(frozen=True, slots=True)
class SlackConfig:
    webhook_url: str


@dataclass(frozen=True, slots=True)
class EmailConfig:
    smtp_host: str
    smtp_port: int
    smtp_user: str
    smtp_password: str
    from_addr: str
    to_addrs: list[str]
    subject_prefix: str = "[모빌리티 공고 모니터]"
    use_starttls: bool = True
    max_items_per_email: int = 30


@dataclass(frozen=True, slots=True)
class DiscordConfig:
    webhook_url: str


@dataclass(frozen=True, slots=True)
class WebhookConfig:
    url: str
    headers: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class ChannelsConfig:
    slack: SlackConfig | None = None
    email: EmailConfig | None = None
    discord: DiscordConfig | None = None
    webhook: WebhookConfig | None = None


def _resolve_env(env_name: str, fallback: str = "") -> str:
    """Resolve an environment variable reference or return the value as-is."""
    return os.environ.get(env_name, fallback)


def _parse_slack(data: dict[str, Any]) -> SlackConfig | None:
    if not data.get("enabled", False):
        return None
    url = _resolve_env(data.get("webhook_url_env", "SLACK_WEBHOOK_URL"))
    if not url:
        return None
    return SlackConfig(webhook_url=url)


def _parse_email(data: dict[str, Any]) -> EmailConfig | None:
    if not data.get("enabled", False):
        return None
    smtp = data.get("smtp", {})
    message = data.get("message", {})

    host = _resolve_env(smtp.get("host_env", "SMTP_HOST"))
    port_str = _resolve_env(smtp.get("port_env", "SMTP_PORT"), "587")
    user = _resolve_env(smtp.get("user_env", "SMTP_USER"))
    password = _resolve_env(smtp.get("pass_env", "SMTP_PASS"))
    from_addr = _resolve_env(message.get("from_env", "SMTP_USER"))
    to_raw = _resolve_env(message.get("to_env", "MAIL_TO"))

    if not all([host, user, password, to_raw]):
        return None

    to_addrs = [addr.strip() for addr in to_raw.split(",") if addr.strip()]
    if not to_addrs:
        return None

    return EmailConfig(
        smtp_host=host,
        smtp_port=int(port_str),
        smtp_user=user,
        smtp_password=password,
        from_addr=from_addr or user,
        to_addrs=to_addrs,
        subject_prefix=message.get("subject_prefix", "[모빌리티 공고 모니터]"),
        use_starttls=smtp.get("use_starttls", True),
        max_items_per_email=message.get("max_items_per_email", 30),
    )


def _parse_discord(data: dict[str, Any]) -> DiscordConfig | None:
    if not data.get("enabled", False):
        return None
    url = _resolve_env(data.get("webhook_url_env", "DISCORD_WEBHOOK_URL"))
    if not url:
        return None
    return DiscordConfig(webhook_url=url)


def _parse_webhook(data: dict[str, Any]) -> WebhookConfig | None:
    if not data.get("enabled", False):
        return None
    url = _resolve_env(data.get("url_env", "WEBHOOK_URL"))
    if not url:
        return None
    headers = data.get("headers", {})
    return WebhookConfig(url=url, headers=headers)


def load_config(config_path: Path) -> ChannelsConfig:
    """Load channel configuration from a YAML file.

    Returns a ``ChannelsConfig`` with only the enabled channels populated.
    Raises ``ConfigError`` on parse failures.
    """
    try:
        raw = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise ConfigError(f"Config file not found: {config_path}") from None
    except yaml.YAMLError as exc:
        raise ConfigError(f"Invalid YAML: {exc}") from exc

    if not isinstance(raw, dict):
        raise ConfigError("Config file must be a YAML mapping")

    channels = raw.get("channels", {})
    return ChannelsConfig(
        slack=_parse_slack(channels.get("slack", {})),
        email=_parse_email(channels.get("email", raw.get("email", {}))),
        discord=_parse_discord(channels.get("discord", {})),
        webhook=_parse_webhook(channels.get("webhook", {})),
    )


def channels_from_env(
    *,
    slack_url: str = "",
    discord_url: str = "",
    webhook_url: str = "",
) -> ChannelsConfig:
    """Build channel config purely from environment variables / explicit args.

    This is the fallback path when no YAML config is provided.
    """
    slack = SlackConfig(webhook_url=slack_url) if slack_url else None
    discord = DiscordConfig(webhook_url=discord_url) if discord_url else None
    webhook = WebhookConfig(url=webhook_url) if webhook_url else None
    return ChannelsConfig(slack=slack, discord=discord, webhook=webhook)
