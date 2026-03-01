"""Shared fixtures and httpx MockTransport helpers."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import httpx
import pytest

from mobility_rfp_monitor.models import Announcement, AnnouncementSource

FIXTURES = Path(__file__).parent / "fixtures"


def load_fixture(name: str) -> dict[str, Any]:
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


def make_mock_transport(
    responses: dict[str, tuple[int, dict[str, Any]]],
) -> httpx.MockTransport:
    """Create a MockTransport that maps URL path substrings to (status, json) pairs."""

    def handler(request: httpx.Request) -> httpx.Response:
        url = str(request.url)
        for path_fragment, (status, body) in responses.items():
            if path_fragment in url:
                return httpx.Response(status, json=body)
        return httpx.Response(404, json={"error": "not found"})

    return httpx.MockTransport(handler)


@pytest.fixture()
def sample_announcement() -> Announcement:
    return Announcement(
        id="mss-자율주행-2025",
        source=AnnouncementSource.MSS,
        title="자율주행 모빌리티 기술개발",
        description="자율주행 기반 스마트모빌리티 서비스",
        url="",
        published_at="2025",
        organization="중소기업기술정보진흥원",
    )


@pytest.fixture()
def sample_announcement_no_match() -> Announcement:
    return Announcement(
        id="mss-제조설비-2025",
        source=AnnouncementSource.MSS,
        title="제조현장 설비 고도화",
        description="스마트 제조혁신",
        url="",
        published_at="2025",
        organization="중소기업기술정보진흥원",
    )
