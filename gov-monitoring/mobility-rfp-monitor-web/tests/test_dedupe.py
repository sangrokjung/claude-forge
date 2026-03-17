"""Phase 5: Deduplication tests."""

from __future__ import annotations

from app.models import SeenNotice, User
from app.auth.password import hash_password
from app.monitoring.dedupe import filter_unseen
from app.monitoring.dto import NormalizedNotice


def _make_notice(source: str = "test", item_id: str = "1") -> NormalizedNotice:
    return NormalizedNotice(
        source=source,
        source_item_id=item_id,
        title="Test Notice",
        agency="TestOrg",
        summary="summary",
        url="",
        deadline="",
        published_at="2026-01-01",
        fetched_at="2026-03-02T00:00:00",
    )


def test_dedupe_allows_new(db_session):
    user = User(email="dedup@test.com", hashed_password=hash_password("pass"))
    db_session.add(user)
    db_session.flush()

    notices = [_make_notice("src", "new-1")]
    result = filter_unseen(user.id, notices, db_session)
    assert len(result) == 1


def test_dedupe_filters_seen(db_session):
    user = User(email="dedup2@test.com", hashed_password=hash_password("pass"))
    db_session.add(user)
    db_session.flush()

    db_session.add(SeenNotice(user_id=user.id, source_item_uid="src:seen-1"))
    db_session.flush()

    notices = [_make_notice("src", "seen-1")]
    result = filter_unseen(user.id, notices, db_session)
    assert len(result) == 0


def test_dedupe_mixed(db_session):
    user = User(email="dedup3@test.com", hashed_password=hash_password("pass"))
    db_session.add(user)
    db_session.flush()

    db_session.add(SeenNotice(user_id=user.id, source_item_uid="src:old"))
    db_session.flush()

    notices = [_make_notice("src", "old"), _make_notice("src", "new")]
    result = filter_unseen(user.id, notices, db_session)
    assert len(result) == 1
    assert result[0].source_item_id == "new"
