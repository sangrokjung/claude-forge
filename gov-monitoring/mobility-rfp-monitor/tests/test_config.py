"""Tests for config.py — YAML configuration loader."""

from __future__ import annotations

from pathlib import Path

import pytest

from mobility_rfp_monitor.config import (
    ChannelsConfig,
    channels_from_env,
    load_config,
)
from mobility_rfp_monitor.exceptions import ConfigError


class TestLoadConfig:
    def test_load_valid_config(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("SLACK_WEBHOOK_URL", "https://hooks.slack.com/test")
        config_file = tmp_path / "config.yaml"
        config_file.write_text(
            """
channels:
  slack:
    enabled: true
    webhook_url_env: SLACK_WEBHOOK_URL
  discord:
    enabled: false
""",
            encoding="utf-8",
        )
        cfg = load_config(config_file)
        assert cfg.slack is not None
        assert cfg.slack.webhook_url == "https://hooks.slack.com/test"
        assert cfg.discord is None
        assert cfg.email is None

    def test_file_not_found(self, tmp_path: Path) -> None:
        with pytest.raises(ConfigError, match="not found"):
            load_config(tmp_path / "missing.yaml")

    def test_invalid_yaml(self, tmp_path: Path) -> None:
        config_file = tmp_path / "bad.yaml"
        config_file.write_text(": : : invalid", encoding="utf-8")
        with pytest.raises(ConfigError, match="Invalid YAML"):
            load_config(config_file)

    def test_non_mapping_yaml(self, tmp_path: Path) -> None:
        config_file = tmp_path / "list.yaml"
        config_file.write_text("- item1\n- item2", encoding="utf-8")
        with pytest.raises(ConfigError, match="mapping"):
            load_config(config_file)

    def test_email_config(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("SMTP_HOST", "smtp.example.com")
        monkeypatch.setenv("SMTP_PORT", "587")
        monkeypatch.setenv("SMTP_USER", "user@example.com")
        monkeypatch.setenv("SMTP_PASS", "secret")
        monkeypatch.setenv("MAIL_TO", "a@b.com,c@d.com")
        config_file = tmp_path / "config.yaml"
        config_file.write_text(
            """
channels:
  email:
    enabled: true
    smtp:
      host_env: SMTP_HOST
      port_env: SMTP_PORT
      user_env: SMTP_USER
      pass_env: SMTP_PASS
      use_starttls: true
    message:
      from_env: SMTP_USER
      to_env: MAIL_TO
      subject_prefix: "[Test]"
      max_items_per_email: 20
""",
            encoding="utf-8",
        )
        cfg = load_config(config_file)
        assert cfg.email is not None
        assert cfg.email.smtp_host == "smtp.example.com"
        assert cfg.email.smtp_port == 587
        assert cfg.email.to_addrs == ["a@b.com", "c@d.com"]
        assert cfg.email.subject_prefix == "[Test]"
        assert cfg.email.max_items_per_email == 20

    def test_disabled_email_returns_none(self, tmp_path: Path) -> None:
        config_file = tmp_path / "config.yaml"
        config_file.write_text(
            """
channels:
  email:
    enabled: false
""",
            encoding="utf-8",
        )
        cfg = load_config(config_file)
        assert cfg.email is None

    def test_missing_env_returns_none(self, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.delenv("SLACK_WEBHOOK_URL", raising=False)
        config_file = tmp_path / "config.yaml"
        config_file.write_text(
            """
channels:
  slack:
    enabled: true
    webhook_url_env: SLACK_WEBHOOK_URL
""",
            encoding="utf-8",
        )
        cfg = load_config(config_file)
        assert cfg.slack is None


class TestChannelsFromEnv:
    def test_slack_from_env(self) -> None:
        cfg = channels_from_env(slack_url="https://hooks.slack.com/test")
        assert cfg.slack is not None
        assert cfg.slack.webhook_url == "https://hooks.slack.com/test"
        assert cfg.discord is None
        assert cfg.webhook is None

    def test_discord_from_env(self) -> None:
        cfg = channels_from_env(discord_url="https://discord.com/api/webhooks/test")
        assert cfg.discord is not None
        assert cfg.slack is None

    def test_no_channels(self) -> None:
        cfg = channels_from_env()
        assert cfg.slack is None
        assert cfg.discord is None
        assert cfg.webhook is None
        assert cfg.email is None

    def test_multiple_channels(self) -> None:
        cfg = channels_from_env(
            slack_url="https://hooks.slack.com/test",
            webhook_url="https://example.com/hook",
        )
        assert cfg.slack is not None
        assert cfg.webhook is not None
