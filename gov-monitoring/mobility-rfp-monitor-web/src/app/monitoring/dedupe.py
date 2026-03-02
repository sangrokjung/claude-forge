"""SQLite-based deduplication for NormalizedNotice."""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.models import SeenNotice
from app.monitoring.dto import NormalizedNotice


def filter_unseen(
    user_id: int,
    notices: list[NormalizedNotice],
    session: Session,
) -> list[NormalizedNotice]:
    """Return only notices not previously seen by this user.

    Also records new items in SeenNotice table.
    """
    if not notices:
        return []

    uids = [n.source_item_uid for n in notices]
    existing = (
        session.query(SeenNotice.source_item_uid)
        .filter(
            SeenNotice.user_id == user_id,
            SeenNotice.source_item_uid.in_(uids),
        )
        .all()
    )
    seen_set = {row[0] for row in existing}

    new_notices: list[NormalizedNotice] = []
    for notice in notices:
        if notice.source_item_uid not in seen_set:
            new_notices.append(notice)
            session.add(SeenNotice(user_id=user_id, source_item_uid=notice.source_item_uid))

    session.flush()
    return new_notices
