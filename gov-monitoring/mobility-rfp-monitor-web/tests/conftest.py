"""Shared test fixtures."""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.db import create_tables, get_engine, get_session_factory, _engines, _session_factories
from app.main import create_app
from app.settings import Settings

FIXTURES_DIR = Path(__file__).parent / "fixtures"


@pytest.fixture()
def settings():
    return Settings(
        jwt_secret_key="test-secret-key-for-testing",
        database_url="sqlite://",
        smtp_host="localhost",
        smtp_port=587,
        smtp_user="test@test.com",
        smtp_pass="testpass",
        config_path=str(FIXTURES_DIR.parent.parent / "config.example.yaml"),
        data_go_kr_api_key="test-api-key",
    )


@pytest.fixture()
def app(settings):
    _engines.clear()
    _session_factories.clear()
    application = create_app(settings)
    yield application


@pytest.fixture()
def client(app):
    return TestClient(app)


@pytest.fixture()
def db_session(app):
    factory = get_session_factory(app.state.engine)
    session = factory()
    yield session
    session.close()


@pytest.fixture()
def mss_response_data():
    with open(FIXTURES_DIR / "mss_response.json", encoding="utf-8") as f:
        return json.load(f)


@pytest.fixture()
def g2b_bid_response_data():
    with open(FIXTURES_DIR / "g2b_bid_response.json", encoding="utf-8") as f:
        return json.load(f)


@pytest.fixture()
def registered_client(client):
    """Return a TestClient with an authenticated session (registered user)."""
    client.post("/register", data={"email": "user@test.com", "password": "password123"})
    return client
