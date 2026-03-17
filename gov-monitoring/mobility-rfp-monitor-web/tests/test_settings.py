"""Phase 1: Settings tests."""

from __future__ import annotations

import pytest
from pydantic import ValidationError

from app.settings import Settings


def test_settings_requires_jwt_secret():
    with pytest.raises(ValidationError):
        Settings()  # type: ignore[call-arg]


def test_settings_loads_with_jwt_secret():
    s = Settings(jwt_secret_key="test-secret")  # type: ignore[call-arg]
    assert s.jwt_secret_key == "test-secret"
    assert s.database_url == "sqlite:///./rfp_monitor.db"


def test_app_boots(client):
    response = client.get("/")
    assert response.status_code == 200
    assert "Mobility RFP Monitor" in response.text
