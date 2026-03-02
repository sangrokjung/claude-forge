"""Phase 7: Monitoring usecase tests."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import httpx

from app.auth.password import hash_password
from app.models import AlertConfig, User
from app.monitoring.dto import NormalizedNotice
from app.monitoring.sources.base import FieldMappingEntry, SourceConfig
from app.monitoring.usecase import run_monitoring_for_user


def _make_source_config(name: str = "test") -> SourceConfig:
    return SourceConfig(
        name=name,
        base_url="https://api.example.com",
        path="test",
        service_key_env="TEST_KEY",
        response_data_path="data",
        field_mapping={
            "title": FieldMappingEntry(candidates=["title"]),
            "item_id": FieldMappingEntry(candidates=["id"]),
        },
    )


def _mock_fetch_response(items: list[dict]) -> httpx.Response:
    import json
    return httpx.Response(200, json={"data": items})


@patch("app.monitoring.sources.generic_client.fetch_json")
def test_run_monitoring_returns_result(mock_fetch, db_session):
    mock_fetch.return_value = {
        "data": [
            {"title": "자율주행 프로젝트", "id": "1"},
            {"title": "사무용품 구매", "id": "2"},
        ]
    }

    user = User(email="run@test.com", hashed_password=hash_password("pass"))
    db_session.add(user)
    db_session.flush()

    config = _make_source_config()
    result = run_monitoring_for_user(
        user_id=user.id,
        source_configs=[config],
        since_hours=24,
        session=db_session,
    )

    assert result.total_fetched == 2
    assert result.keyword_matched == 1
    assert result.new_items == 1
    assert result.notices[0].title == "자율주행 프로젝트"


@patch("app.monitoring.sources.generic_client.fetch_json")
def test_run_monitoring_source_failure_isolated(mock_fetch, db_session):
    mock_fetch.side_effect = Exception("API down")

    user = User(email="fail@test.com", hashed_password=hash_password("pass"))
    db_session.add(user)
    db_session.flush()

    config = _make_source_config()
    result = run_monitoring_for_user(
        user_id=user.id,
        source_configs=[config],
        since_hours=24,
        session=db_session,
    )

    assert result.total_fetched == 0
    assert len(result.errors) == 1
