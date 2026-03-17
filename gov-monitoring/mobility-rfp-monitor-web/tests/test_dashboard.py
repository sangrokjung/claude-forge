"""Phase 3: Dashboard tests."""

from __future__ import annotations


def test_dashboard_shows_user_email_as_default(registered_client):
    response = registered_client.get("/dashboard")
    assert response.status_code == 200
    assert "user@test.com" in response.text


def test_save_recipients_over_10_fails(registered_client):
    emails = ",".join(f"user{i}@test.com" for i in range(11))
    response = registered_client.post(
        "/dashboard",
        data={"recipients": emails, "since_hours": 24, "enabled_sources": "kstartup"},
    )
    assert response.status_code == 400
    assert "Maximum 10" in response.text


def test_save_valid_config_persists(registered_client):
    registered_client.post(
        "/dashboard",
        data={
            "recipients": "a@test.com,b@test.com",
            "since_hours": 48,
            "enabled_sources": "g2b_bid",
        },
    )
    response = registered_client.get("/dashboard")
    assert "a@test.com" in response.text
    assert "b@test.com" in response.text


def test_save_invalid_email_fails(registered_client):
    response = registered_client.post(
        "/dashboard",
        data={"recipients": "not-an-email", "since_hours": 24, "enabled_sources": "kstartup"},
    )
    assert response.status_code == 400
    assert "Invalid email" in response.text
