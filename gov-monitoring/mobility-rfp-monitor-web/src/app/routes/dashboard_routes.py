"""Dashboard routes: alert config view and save."""

from __future__ import annotations

import re

from fastapi import APIRouter, Form, Request
from fastapi.responses import HTMLResponse, RedirectResponse

from app.auth.jwt_cookie import require_auth
from app.db import get_session_factory
from app.models import AlertConfig, User

router = APIRouter()

_EMAIL_RE = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_MAX_RECIPIENTS = 10


def validate_recipients(raw: str) -> tuple[list[str], str | None]:
    """Parse comma-separated emails. Returns (emails, error_or_none)."""
    emails = [e.strip() for e in raw.split(",") if e.strip()]
    if not emails:
        return [], "At least one recipient is required"
    if len(emails) > _MAX_RECIPIENTS:
        return [], f"Maximum {_MAX_RECIPIENTS} recipients allowed"
    for email in emails:
        if not _EMAIL_RE.match(email):
            return [], f"Invalid email: {email}"
    return emails, None


@router.get("/dashboard", response_model=None)
def dashboard(request: Request) -> HTMLResponse | RedirectResponse:
    auth = require_auth(request)
    if isinstance(auth, RedirectResponse):
        return auth
    user: User = auth

    templates = request.app.state.templates
    session_factory = get_session_factory(request.app.state.engine)

    with session_factory() as session:
        config = session.query(AlertConfig).filter_by(user_id=user.id).first()

    recipients = config.recipients if config else user.email
    since_hours = config.since_hours if config else 24
    enabled_sources = config.enabled_sources if config else "kstartup,g2b_bid"

    return templates.TemplateResponse(
        request,
        "dashboard.html",
        {
            "user": user,
            "recipients": recipients,
            "since_hours": since_hours,
            "enabled_sources": enabled_sources,
        },
    )


@router.post("/dashboard", response_model=None)
def save_config(
    request: Request,
    recipients: str = Form(""),
    since_hours: int = Form(24),
    enabled_sources: str = Form("kstartup,g2b_bid"),
) -> HTMLResponse | RedirectResponse:
    auth = require_auth(request)
    if isinstance(auth, RedirectResponse):
        return auth
    user: User = auth

    templates = request.app.state.templates

    emails, error = validate_recipients(recipients)
    if error:
        return templates.TemplateResponse(
            request,
            "dashboard.html",
            {
                "user": user,
                "recipients": recipients,
                "since_hours": since_hours,
                "enabled_sources": enabled_sources,
                "error": error,
            },
            status_code=400,
        )

    session_factory = get_session_factory(request.app.state.engine)
    with session_factory() as session:
        config = session.query(AlertConfig).filter_by(user_id=user.id).first()
        if config:
            config.recipients = ",".join(emails)
            config.since_hours = since_hours
            config.enabled_sources = enabled_sources
        else:
            config = AlertConfig(
                user_id=user.id,
                recipients=",".join(emails),
                since_hours=since_hours,
                enabled_sources=enabled_sources,
            )
            session.add(config)
        session.commit()

    return templates.TemplateResponse(
        request,
        "dashboard.html",
        {
            "user": user,
            "recipients": ",".join(emails),
            "since_hours": since_hours,
            "enabled_sources": enabled_sources,
            "success": "Settings saved",
        },
    )
