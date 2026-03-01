"""Immutable state management for duplicate prevention.

State is persisted as a ``.state.json`` file.  Every mutation returns a
*new* ``State`` instance — the original is never modified.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

from mobility_rfp_monitor.exceptions import StateFileCorruptedError
from mobility_rfp_monitor.models import Announcement


@dataclass(frozen=True, slots=True)
class SeenEntry:
    """A previously seen announcement identifier."""

    id: str
    first_seen: str


@dataclass(frozen=True, slots=True)
class State:
    """Immutable monitor state."""

    seen: frozenset[SeenEntry] = frozenset()
    last_run: str = ""


def load_state(path: Path) -> State:
    """Load state from *path*.  Returns empty state if file is missing."""
    if not path.exists():
        return State()
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise StateFileCorruptedError(str(path), str(exc)) from exc

    try:
        entries = frozenset(
            SeenEntry(id=e["id"], first_seen=e["first_seen"])
            for e in raw.get("seen", [])
        )
        return State(seen=entries, last_run=raw.get("last_run", ""))
    except (KeyError, TypeError) as exc:
        raise StateFileCorruptedError(str(path), str(exc)) from exc


def save_state(state: State, path: Path) -> None:
    """Serialise *state* to JSON at *path*."""
    data = {
        "seen": sorted(
            [{"id": e.id, "first_seen": e.first_seen} for e in state.seen],
            key=lambda e: e["id"],
        ),
        "last_run": state.last_run,
    }
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


_DEFAULT_MAX_ENTRIES = 5000


def prune_state(state: State, max_entries: int = _DEFAULT_MAX_ENTRIES) -> State:
    """Return a new ``State`` with at most *max_entries* seen items.

    Oldest entries (by ``first_seen``) are removed first.
    The original *state* is not modified.
    """
    if len(state.seen) <= max_entries:
        return state
    kept = sorted(state.seen, key=lambda e: e.first_seen, reverse=True)[:max_entries]
    return State(seen=frozenset(kept), last_run=state.last_run)


def filter_unseen(
    announcements: list[Announcement],
    state: State,
) -> tuple[list[Announcement], State]:
    """Return ``(new_items, updated_state)`` — original *state* is untouched.

    Duplicate IDs within the same batch are also deduplicated (first wins).
    """
    seen_ids = {e.id for e in state.seen}
    new_items: list[Announcement] = []
    batch_seen: set[str] = set()
    for a in announcements:
        if a.id not in seen_ids and a.id not in batch_seen:
            new_items.append(a)
            batch_seen.add(a.id)

    now = datetime.now(timezone.utc).isoformat()
    new_entries = frozenset(
        SeenEntry(id=a.id, first_seen=now) for a in new_items
    )
    updated_state = State(
        seen=state.seen | new_entries,
        last_run=now,
    )
    return new_items, updated_state
