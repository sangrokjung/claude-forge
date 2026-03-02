"""Custom exceptions for the mobility-rfp-monitor package."""

from __future__ import annotations


class ApiError(Exception):
    """Raised when an external API returns a non-success response."""

    def __init__(self, source: str, status_code: int, detail: str) -> None:
        self.source = source
        self.status_code = status_code
        self.detail = detail
        super().__init__(f"[{source}] HTTP {status_code}: {detail}")


class ApiKeyMissingError(Exception):
    """Raised when a required API key environment variable is unset."""

    def __init__(self, env_var: str) -> None:
        self.env_var = env_var
        super().__init__(f"Required environment variable not set: {env_var}")


class StateFileCorruptedError(Exception):
    """Raised when the state file cannot be parsed."""

    def __init__(self, path: str, reason: str) -> None:
        self.path = path
        self.reason = reason
        super().__init__(f"Corrupted state file {path}: {reason}")


class SlackNotificationError(Exception):
    """Raised when the Slack webhook call fails."""

    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(f"Slack notification failed HTTP {status_code}: {detail}")


class EmailNotificationError(Exception):
    """Raised when SMTP email delivery fails."""

    def __init__(self, detail: str) -> None:
        self.detail = detail
        super().__init__(f"Email notification failed: {detail}")


class DiscordNotificationError(Exception):
    """Raised when the Discord webhook call fails."""

    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(f"Discord notification failed HTTP {status_code}: {detail}")


class WebhookNotificationError(Exception):
    """Raised when a generic webhook call fails."""

    def __init__(self, status_code: int, detail: str) -> None:
        self.status_code = status_code
        self.detail = detail
        super().__init__(f"Webhook notification failed HTTP {status_code}: {detail}")


class ConfigError(Exception):
    """Raised when configuration file is invalid or missing."""

    def __init__(self, detail: str) -> None:
        self.detail = detail
        super().__init__(f"Configuration error: {detail}")
