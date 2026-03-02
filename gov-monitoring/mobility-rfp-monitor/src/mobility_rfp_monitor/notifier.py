"""Backward-compatible re-exports from channels.slack.

Deprecated: import directly from ``mobility_rfp_monitor.channels.slack``.
"""

from mobility_rfp_monitor.channels.slack import format_slack_message, SlackChannel

__all__ = ["format_slack_message", "send_slack_notification"]


def send_slack_notification(
    http_client,
    webhook_url: str,
    announcements,
) -> int:
    """Legacy wrapper — delegates to ``SlackChannel.send()``."""
    channel = SlackChannel(http_client, webhook_url)
    return channel.send(announcements)
