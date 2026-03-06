"""Authentication routes: register, login, logout."""

from __future__ import annotations

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.exc import IntegrityError

from app.auth.jwt_cookie import (
    clear_auth_cookie,
    create_access_token,
    set_auth_cookie,
)
from app.auth.password import hash_password, verify_password
from app.db import get_session_factory
from app.models import AlertConfig, User

router = APIRouter()


@router.get("/register", response_class=HTMLResponse)
def register_page(request: Request) -> HTMLResponse:
    templates = request.app.state.templates
    return templates.TemplateResponse(request, "register.html")


@router.post("/register", response_model=None)
def register(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
) -> RedirectResponse | HTMLResponse:
    settings = request.app.state.settings
    templates = request.app.state.templates
    session_factory = get_session_factory(request.app.state.engine)

    with session_factory() as session:
        user = User(email=email, hashed_password=hash_password(password))
        session.add(user)
        try:
            session.flush()
        except IntegrityError:
            session.rollback()
            return templates.TemplateResponse(
                request,
                "register.html",
                {"error": "Email already registered"},
                status_code=409,
            )

        alert_config = AlertConfig(user_id=user.id, recipients=email)
        session.add(alert_config)
        session.commit()

        token = create_access_token(
            user.id,
            user.email,
            settings.jwt_secret_key,
            settings.jwt_algorithm,
            settings.jwt_expire_hours,
        )

    response = RedirectResponse("/dashboard", status_code=303)
    set_auth_cookie(response, token)
    return response


@router.get("/login", response_class=HTMLResponse)
def login_page(request: Request) -> HTMLResponse:
    templates = request.app.state.templates
    return templates.TemplateResponse(request, "login.html")


@router.post("/login", response_model=None)
def login(
    request: Request,
    email: str = Form(...),
    password: str = Form(...),
) -> RedirectResponse | HTMLResponse:
    settings = request.app.state.settings
    templates = request.app.state.templates
    session_factory = get_session_factory(request.app.state.engine)

    with session_factory() as session:
        user = session.query(User).filter_by(email=email).first()

    if user is None or not verify_password(password, user.hashed_password):
        return templates.TemplateResponse(
            request,
            "login.html",
            {"error": "Invalid email or password"},
            status_code=401,
        )

    token = create_access_token(
        user.id,
        user.email,
        settings.jwt_secret_key,
        settings.jwt_algorithm,
        settings.jwt_expire_hours,
    )
    response = RedirectResponse("/dashboard", status_code=303)
    set_auth_cookie(response, token)
    return response


@router.get("/logout")
def logout() -> RedirectResponse:
    response = RedirectResponse("/", status_code=303)
    clear_auth_cookie(response)
    return response
