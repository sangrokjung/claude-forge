"""Channel protocol — structural typing interface for notification channels."""

from __future__ import annotations

from typing import Protocol, Sequence

from mobility_rfp_monitor.models import Announcement


class NotificationChannel(Protocol):
    """Interface every notification channel must satisfy.

    Uses structural typing (Protocol) instead of ABC so channels
    don't need to inherit — just implement the shape.
    """

    @property
    def channel_name(self) -> str:
        """Human-readable channel identifier (e.g. ``'slack'``, ``'email'``)."""
        ...

    def send(self, announcements: Sequence[Announcement]) -> int:
        """Deliver *announcements* and return the count of items sent."""
        ...
