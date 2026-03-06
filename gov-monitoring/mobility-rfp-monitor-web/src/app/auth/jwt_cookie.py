"""JWT token creation, cookie handling, and authentication dependency."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from fastapi import Request
from fastapi.responses import RedirectResponse
from jose import JWTError, jwt

from app.db import get_session_factory
from app.models import User

COOKIE_NAME = "access_token"


def create_access_token(
    user_id: int,
    email: str,
    secret_key: str,
    algorithm: str = "HS256",
    expire_hours: int = 72,
) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=expire_hours)
    payload = {"sub": str(user_id), "email": email, "exp": expire}
    return jwt.encode(payload, secret_key, algorithm=algorithm)


def set_auth_cookie(response: RedirectResponse, token: str) -> None:
    response.set_cookie(
        key=COOKIE_NAME,
        value=token,
        httponly=True,
        samesite="lax",
        max_age=72 * 3600,
    )


def clear_auth_cookie(response: RedirectResponse) -> None:
    response.delete_cookie(key=COOKIE_NAME)


def get_current_user(request: Request) -> User | None:
    token = request.cookies.get(COOKIE_NAME)
    if not token:
        return None

    settings = request.app.state.settings
    try:
        payload = jwt.decode(token, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm])
        user_id = int(payload["sub"])
    except (JWTError, KeyError, ValueError):
        return None

    session_factory = get_session_factory(request.app.state.engine)
    with session_factory() as session:
        return session.get(User, user_id)


def require_auth(request: Request) -> User | RedirectResponse:
    user = get_current_user(request)
    if user is None:
        return RedirectResponse("/login", status_code=303)
    return user
