"""Tests for client.py — API fetch with MockTransport."""

from __future__ import annotations

import httpx
import pytest

from mobility_rfp_monitor.client import fetch_g2b_bids, fetch_mss
from mobility_rfp_monitor.exceptions import ApiError
from mobility_rfp_monitor.models import AnnouncementSource
from tests.conftest import load_fixture, make_mock_transport


class TestFetchMss:
    def test_normal_response(self) -> None:
        fixture = load_fixture("mss_response.json")
        transport = make_mock_transport({"odcloud.kr": (200, fixture)})
        with httpx.Client(transport=transport) as client:
            results = fetch_mss(client, "test-key")
        assert len(results) == 3
        assert results[0].source == AnnouncementSource.MSS
        assert "자율주행" in results[0].title

    def test_empty_response(self) -> None:
        empty = {"currentCount": 0, "data": [], "totalCount": 0}
        transport = make_mock_transport({"odcloud.kr": (200, empty)})
        with httpx.Client(transport=transport) as client:
            results = fetch_mss(client, "test-key")
        assert results == []

    def test_http_error(self) -> None:
        transport = make_mock_transport({"odcloud.kr": (401, {"code": -401, "msg": "Unauthorized"})})
        with httpx.Client(transport=transport) as client:
            with pytest.raises(ApiError) as exc_info:
                fetch_mss(client, "bad-key")
        assert exc_info.value.status_code == 401


class TestFetchG2bBids:
    def test_normal_response(self) -> None:
        fixture = load_fixture("g2b_bid_response.json")
        transport = make_mock_transport({"BidPublicInfoService": (200, fixture)})
        with httpx.Client(transport=transport) as client:
            results = fetch_g2b_bids(
                client, "test-key", since="202603010000", until="202603020000"
            )
        assert len(results) == 2
        assert results[0].source == AnnouncementSource.G2B_BID
        assert "20260301001" in results[0].id

    def test_empty_response(self) -> None:
        empty = {"response": {"body": {"items": [], "totalCount": 0}}}
        transport = make_mock_transport({"BidPublicInfoService": (200, empty)})
        with httpx.Client(transport=transport) as client:
            results = fetch_g2b_bids(
                client, "test-key", since="202603010000", until="202603020000"
            )
        assert results == []

    def test_http_error(self) -> None:
        transport = make_mock_transport({"BidPublicInfoService": (403, {"error": "forbidden"})})
        with httpx.Client(transport=transport) as client:
            with pytest.raises(ApiError) as exc_info:
                fetch_g2b_bids(
                    client, "test-key", since="202603010000", until="202603020000"
                )
        assert exc_info.value.status_code == 403


# ── TDD Cycle 4: MSS 필드 매핑 엣지케이스 ────────────────────────


class TestMssFieldMapping:
    """실제 MSS API 응답에서 발견된 필드 누락/빈값 패턴."""

    def test_empty_organization_falls_back_to_관리기관(self) -> None:
        """전문기관명이 빈 문자열이면 관리기관명으로 fallback해야 한다."""
        data = {
            "currentCount": 1,
            "data": [
                {
                    "공고명": "테스트 공고",
                    "과제명": "테스트 과제",
                    "사업년도": 2024,
                    "사업명": "기술개발",
                    "전문기관명": "",
                    "관리기관명": "서울지방중소벤처기업청",
                }
            ],
            "totalCount": 1,
        }
        transport = make_mock_transport({"odcloud.kr": (200, data)})
        with httpx.Client(transport=transport) as client:
            results = fetch_mss(client, "test-key")
        assert len(results) == 1
        assert results[0].organization == "서울지방중소벤처기업청"

    def test_missing_organization_fields(self) -> None:
        """전문기관명과 관리기관명 둘 다 없을 때 빈 문자열."""
        data = {
            "currentCount": 1,
            "data": [
                {
                    "공고명": "테스트",
                    "과제명": "테스트",
                    "사업년도": 2024,
                    "사업명": "테스트",
                }
            ],
            "totalCount": 1,
        }
        transport = make_mock_transport({"odcloud.kr": (200, data)})
        with httpx.Client(transport=transport) as client:
            results = fetch_mss(client, "test-key")
        assert results[0].organization == ""

    def test_id_uses_과제명_and_사업년도(self) -> None:
        """ID가 'mss-{과제명}-{사업년도}' 형식인지 확인."""
        data = {
            "currentCount": 1,
            "data": [
                {
                    "공고명": "공고",
                    "과제명": "자율주행 로봇",
                    "사업년도": 2025,
                    "전문기관명": "진흥원",
                }
            ],
            "totalCount": 1,
        }
        transport = make_mock_transport({"odcloud.kr": (200, data)})
        with httpx.Client(transport=transport) as client:
            results = fetch_mss(client, "test-key")
        assert results[0].id == "mss-자율주행 로봇-2025"
