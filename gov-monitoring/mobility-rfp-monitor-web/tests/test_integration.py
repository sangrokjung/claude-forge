"""Phase 8: Integration tests — full user journey."""

from __future__ import annotations

from unittest.mock import MagicMock, patch


def test_full_user_journey(client):
    """Register → Set-Cookie → /dashboard → Save Config → /run → /results."""

    # 1. Register
    response = client.post(
        "/register",
        data={"email": "journey@test.com", "password": "pass123"},
        follow_redirects=False,
    )
    assert response.status_code == 303
    assert "access_token" in response.cookies

    # 2. Dashboard accessible
    response = client.get("/dashboard")
    assert response.status_code == 200
    assert "journey@test.com" in response.text

    # 3. Save config
    response = client.post(
        "/dashboard",
        data={
            "recipients": "journey@test.com,other@test.com",
            "since_hours": 48,
            "enabled_sources": "kstartup,g2b_bid",
        },
    )
    assert response.status_code == 200
    assert "Settings saved" in response.text

    # 4. Test email (mocked SMTP + API)
    with (
        patch("app.routes.monitoring_routes.send_email") as mock_send,
        patch("app.monitoring.sources.generic_client.fetch_json") as mock_fetch,
    ):
        mock_fetch.return_value = {
            "data": [{"공고명": "자율주행 테스트", "과제명": "자율주행 과제", "사업년도": 2026, "전문기관명": "TestOrg"}]
        }

        response = client.post("/test-email")
        assert response.status_code == 200

        if mock_send.called:
            call_kwargs = mock_send.call_args[1]
            assert call_kwargs["to_addrs"] == ["journey@test.com"]

    # 5. Run monitoring (mocked)
    with (
        patch("app.routes.monitoring_routes.send_email") as mock_send,
        patch("app.monitoring.sources.generic_client.fetch_json") as mock_fetch,
    ):
        mock_fetch.return_value = {
            "data": [{"공고명": "전기차 충전인프라", "과제명": "EV 충전", "사업년도": 2026, "전문기관명": "전력공사"}]
        }

        response = client.post("/run", follow_redirects=False)
        assert response.status_code == 303

        if mock_send.called:
            call_kwargs = mock_send.call_args[1]
            assert set(call_kwargs["to_addrs"]) == {"journey@test.com", "other@test.com"}

    # 6. Results
    response = client.get("/results")
    assert response.status_code == 200


def test_unauthenticated_run_redirects(client):
    response = client.post("/run", follow_redirects=False)
    assert response.status_code == 303
    assert "/login" in response.headers["location"]


def test_test_email_sends_to_user_only(client):
    """POST /test-email sends to current user email only, not config recipients."""
    client.post("/register", data={"email": "solo@test.com", "password": "pass123"})
    client.post(
        "/dashboard",
        data={
            "recipients": "solo@test.com,other@test.com,third@test.com",
            "since_hours": 24,
            "enabled_sources": "kstartup",
        },
    )

    with (
        patch("app.routes.monitoring_routes.send_email") as mock_send,
        patch("app.monitoring.sources.generic_client.fetch_json") as mock_fetch,
    ):
        mock_fetch.return_value = {
            "data": [{"공고명": "자율주행 사업", "과제명": "자율주행", "사업년도": 2026, "전문기관명": "Org"}]
        }
        client.post("/test-email")

        if mock_send.called:
            call_kwargs = mock_send.call_args[1]
            assert call_kwargs["to_addrs"] == ["solo@test.com"]


def test_results_shows_history(client):
    """After running monitoring, /results shows the run history."""
    client.post("/register", data={"email": "hist@test.com", "password": "pass123"})

    with (
        patch("app.routes.monitoring_routes.send_email"),
        patch("app.monitoring.sources.generic_client.fetch_json") as mock_fetch,
    ):
        mock_fetch.return_value = {"data": []}
        client.post("/run", follow_redirects=False)

    response = client.get("/results")
    assert response.status_code == 200
