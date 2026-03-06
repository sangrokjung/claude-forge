"""Tests for state.py — load, save, filter_unseen, immutability."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from mobility_rfp_monitor.exceptions import StateFileCorruptedError
from mobility_rfp_monitor.models import Announcement, AnnouncementSource
from mobility_rfp_monitor.state import (
    SeenEntry,
    State,
    filter_unseen,
    load_state,
    save_state,
)


def _make_announcement(id_: str) -> Announcement:
    return Announcement(
        id=id_,
        source=AnnouncementSource.MSS,
        title="Test",
        description="Desc",
        url="",
        published_at="2026-03-01",
        organization="Org",
    )


class TestLoadState:
    def test_missing_file(self, tmp_path: Path) -> None:
        state = load_state(tmp_path / "nonexistent.json")
        assert state.seen == frozenset()
        assert state.last_run == ""

    def test_valid_file(self, tmp_path: Path) -> None:
        path = tmp_path / "state.json"
        path.write_text(
            json.dumps(
                {
                    "seen": [{"id": "test-1", "first_seen": "2026-01-01T00:00:00"}],
                    "last_run": "2026-01-01T00:00:00",
                }
            ),
            encoding="utf-8",
        )
        state = load_state(path)
        assert len(state.seen) == 1
        assert state.last_run == "2026-01-01T00:00:00"

    def test_corrupted_json(self, tmp_path: Path) -> None:
        path = tmp_path / "state.json"
        path.write_text("{invalid json", encoding="utf-8")
        with pytest.raises(StateFileCorruptedError):
            load_state(path)

    def test_missing_keys(self, tmp_path: Path) -> None:
        path = tmp_path / "state.json"
        path.write_text(json.dumps({"seen": [{"bad": "data"}]}), encoding="utf-8")
        with pytest.raises(StateFileCorruptedError):
            load_state(path)


class TestSaveState:
    def test_round_trip(self, tmp_path: Path) -> None:
        path = tmp_path / "state.json"
        original = State(
            seen=frozenset({SeenEntry(id="a-1", first_seen="2026-01-01T00:00:00")}),
            last_run="2026-01-01T00:00:00",
        )
        save_state(original, path)
        loaded = load_state(path)
        assert loaded.seen == original.seen
        assert loaded.last_run == original.last_run

    def test_sorted_output(self, tmp_path: Path) -> None:
        path = tmp_path / "state.json"
        state = State(
            seen=frozenset(
                {
                    SeenEntry(id="z-1", first_seen="2026-01-01"),
                    SeenEntry(id="a-1", first_seen="2026-01-01"),
                }
            ),
            last_run="",
        )
        save_state(state, path)
        data = json.loads(path.read_text(encoding="utf-8"))
        ids = [e["id"] for e in data["seen"]]
        assert ids == ["a-1", "z-1"]


class TestFilterUnseen:
    def test_all_new(self) -> None:
        anns = [_make_announcement("a"), _make_announcement("b")]
        state = State()
        new_items, updated = filter_unseen(anns, state)
        assert len(new_items) == 2
        assert len(updated.seen) == 2

    def test_some_seen(self) -> None:
        anns = [_make_announcement("a"), _make_announcement("b")]
        state = State(seen=frozenset({SeenEntry(id="a", first_seen="2026-01-01")}))
        new_items, updated = filter_unseen(anns, state)
        assert len(new_items) == 1
        assert new_items[0].id == "b"
        assert len(updated.seen) == 2

    def test_all_seen(self) -> None:
        anns = [_make_announcement("a")]
        state = State(seen=frozenset({SeenEntry(id="a", first_seen="2026-01-01")}))
        new_items, updated = filter_unseen(anns, state)
        assert len(new_items) == 0
        assert len(updated.seen) == 1

    def test_original_state_unchanged(self) -> None:
        anns = [_make_announcement("new")]
        original = State()
        _, _ = filter_unseen(anns, original)
        assert original.seen == frozenset()
        assert original.last_run == ""


# ── TDD Cycle 2: State 엣지케이스 ─────────────────────────────────


class TestFilterUnseenConsecutiveCalls:
    """filter_unseen을 연속 호출하면 첫 호출에서 본 항목이 두 번째에서 중복 제거된다."""

    def test_second_call_deduplicates(self) -> None:
        anns_round1 = [_make_announcement("a"), _make_announcement("b")]
        state0 = State()

        new1, state1 = filter_unseen(anns_round1, state0)
        assert len(new1) == 2

        # 라운드 2: a,b 는 이미 seen, c만 새롭다
        anns_round2 = [_make_announcement("a"), _make_announcement("c")]
        new2, state2 = filter_unseen(anns_round2, state1)
        assert len(new2) == 1
        assert new2[0].id == "c"
        assert len(state2.seen) == 3  # a, b, c

    def test_empty_round_preserves_state(self) -> None:
        """빈 리스트로 호출하면 seen은 변하지 않고 last_run만 갱신."""
        state = State(seen=frozenset({SeenEntry(id="x", first_seen="2026-01-01")}))
        new_items, updated = filter_unseen([], state)
        assert new_items == []
        assert len(updated.seen) == 1
        assert updated.last_run != ""  # 갱신됨


class TestFilterUnseenUpdatedStateHasLastRun:
    """반환된 state의 last_run이 ISO 형식 타임스탬프여야 한다."""

    def test_last_run_is_iso_format(self) -> None:
        anns = [_make_announcement("ts1")]
        _, updated = filter_unseen(anns, State())
        # ISO 8601 형태: 2026-03-01T12:00:00+00:00
        assert "T" in updated.last_run
        assert updated.last_run > "2020-01-01"


class TestStateFrozenness:
    """State와 SeenEntry가 진짜 불변인지 확인."""

    def test_state_is_frozen(self) -> None:
        state = State()
        with pytest.raises(AttributeError):
            state.seen = frozenset()  # type: ignore[misc]

    def test_seen_entry_is_frozen(self) -> None:
        entry = SeenEntry(id="a", first_seen="2026-01-01")
        with pytest.raises(AttributeError):
            entry.id = "mutated"  # type: ignore[misc]


class TestSaveLoadKoreanIds:
    """한글 ID를 save/load 라운드트립해도 깨지지 않아야 한다."""

    def test_korean_id_round_trip(self, tmp_path: Path) -> None:
        path = tmp_path / "state.json"
        state = State(
            seen=frozenset({SeenEntry(id="공고-가나다-001", first_seen="2026-03-01")}),
            last_run="2026-03-01T00:00:00",
        )
        save_state(state, path)

        # JSON에 한글이 escape 없이 저장되었는지
        raw = path.read_text(encoding="utf-8")
        assert "공고-가나다-001" in raw

        loaded = load_state(path)
        assert loaded.seen == state.seen


class TestLoadStateEmptySeen:
    """seen이 빈 배열인 JSON도 정상 로드해야 한다."""

    def test_empty_seen_array(self, tmp_path: Path) -> None:
        path = tmp_path / "state.json"
        path.write_text(json.dumps({"seen": [], "last_run": ""}), encoding="utf-8")
        state = load_state(path)
        assert state.seen == frozenset()
        assert state.last_run == ""


class TestFilterUnseenDuplicateInBatch:
    """같은 배치 안에 동일 ID가 있으면 하나만 new_items에 포함해야 한다."""

    def test_duplicate_ids_in_same_batch(self) -> None:
        ann1 = _make_announcement("dup")
        ann2 = _make_announcement("dup")
        new_items, updated = filter_unseen([ann1, ann2], State())
        assert len(new_items) == 1
        assert new_items[0].id == "dup"
        assert len(updated.seen) == 1

    def test_first_occurrence_wins(self) -> None:
        """같은 ID가 여러 개면 첫 번째가 반환되어야 한다."""
        ann1 = Announcement(
            id="dup",
            source=AnnouncementSource.MSS,
            title="First",
            description="",
            url="",
            published_at="",
            organization="",
        )
        ann2 = Announcement(
            id="dup",
            source=AnnouncementSource.MSS,
            title="Second",
            description="",
            url="",
            published_at="",
            organization="",
        )
        new_items, _ = filter_unseen([ann1, ann2], State())
        assert len(new_items) == 1
        assert new_items[0].title == "First"


class TestSaveStateCreatesParent:
    """상위 디렉토리가 없으면 save_state가 실패해야 한다 (자동 생성하지 않음)."""

    def test_missing_parent_raises(self, tmp_path: Path) -> None:
        path = tmp_path / "nonexistent" / "state.json"
        state = State(seen=frozenset(), last_run="")
        with pytest.raises(FileNotFoundError):
            save_state(state, path)


# ── TDD Cycle 5: State pruning ───────────────────────────────────

from mobility_rfp_monitor.state import prune_state


class TestPruneState:
    """오래된 항목을 제거하여 state 크기를 제한한다."""

    def test_prune_keeps_recent(self) -> None:
        """max_entries 이내면 아무것도 제거하지 않는다."""
        entries = frozenset(
            SeenEntry(id=f"item-{i}", first_seen="2026-03-01T00:00:00+00:00")
            for i in range(5)
        )
        state = State(seen=entries, last_run="2026-03-01T12:00:00+00:00")
        pruned = prune_state(state, max_entries=10)
        assert len(pruned.seen) == 5
        assert pruned.last_run == state.last_run

    def test_prune_removes_oldest(self) -> None:
        """max_entries 초과 시 first_seen이 가장 오래된 것부터 제거."""
        old = SeenEntry(id="old", first_seen="2026-01-01T00:00:00+00:00")
        mid = SeenEntry(id="mid", first_seen="2026-02-01T00:00:00+00:00")
        new = SeenEntry(id="new", first_seen="2026-03-01T00:00:00+00:00")
        state = State(seen=frozenset({old, mid, new}), last_run="2026-03-01")
        pruned = prune_state(state, max_entries=2)
        assert len(pruned.seen) == 2
        ids = {e.id for e in pruned.seen}
        assert "old" not in ids
        assert "mid" in ids
        assert "new" in ids

    def test_prune_preserves_immutability(self) -> None:
        """원본 state가 변경되지 않아야 한다."""
        entries = frozenset(
            SeenEntry(id=f"p-{i}", first_seen=f"2026-01-{i+1:02d}T00:00:00+00:00")
            for i in range(5)
        )
        original = State(seen=entries, last_run="2026-03-01")
        pruned = prune_state(original, max_entries=2)
        assert len(original.seen) == 5  # 원본 불변
        assert len(pruned.seen) == 2

    def test_prune_default_max(self) -> None:
        """기본 max_entries 값이 적용되어야 한다."""
        entries = frozenset(
            SeenEntry(id=f"d-{i}", first_seen=f"2026-01-01T00:{i:02d}:00+00:00")
            for i in range(3)
        )
        state = State(seen=entries, last_run="2026-03-01")
        # 기본값은 충분히 크므로 3개는 유지된다
        pruned = prune_state(state)
        assert len(pruned.seen) == 3
