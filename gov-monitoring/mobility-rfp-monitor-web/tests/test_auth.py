"""Phase 2: Authentication tests."""

from __future__ import annotations


def test_register_sets_cookie_and_redirects(client):
    response = client.post(
        "/register",
        data={"email": "new@test.com", "password": "password123"},
        follow_redirects=False,
    )
    assert response.status_code == 303
    assert response.headers["location"] == "/dashboard"
    assert "access_token" in response.cookies


def test_register_then_dashboard_accessible(client):
    client.post("/register", data={"email": "new@test.com", "password": "password123"})
    response = client.get("/dashboard")
    assert response.status_code == 200
    assert "new@test.com" in response.text


def test_unauthenticated_dashboard_redirects(client):
    response = client.get("/dashboard", follow_redirects=False)
    assert response.status_code == 303
    assert "/login" in response.headers["location"]


def test_register_duplicate_email_fails(client):
    client.post("/register", data={"email": "dup@test.com", "password": "pass1"})
    response = client.post(
        "/register",
        data={"email": "dup@test.com", "password": "pass2"},
    )
    assert response.status_code == 409
    assert "already registered" in response.text.lower()


def test_login_success(client):
    client.post("/register", data={"email": "login@test.com", "password": "pass123"})
    response = client.post(
        "/login",
        data={"email": "login@test.com", "password": "pass123"},
        follow_redirects=False,
    )
    assert response.status_code == 303
    assert "access_token" in response.cookies


def test_login_wrong_password(client):
    client.post("/register", data={"email": "login@test.com", "password": "pass123"})
    response = client.post(
        "/login",
        data={"email": "login@test.com", "password": "wrongpass"},
    )
    assert response.status_code == 401


def test_logout_clears_cookie(client):
    client.post("/register", data={"email": "logout@test.com", "password": "pass123"})
    response = client.get("/logout", follow_redirects=False)
    assert response.status_code == 303
    cookies = response.cookies
    assert cookies.get("access_token") is None or cookies.get("access_token") == ""
