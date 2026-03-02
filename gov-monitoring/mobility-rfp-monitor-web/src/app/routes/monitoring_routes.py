"""Monitoring routes: test-email, run, results."""

from __future__ import annotations

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse, RedirectResponse

from app.auth.jwt_cookie import require_auth
from app.db import get_session_factory
from app.models import AlertConfig, FoundNotice, MonitoringRun, User
from app.monitoring.sources.config_loader import load_enabled_configs
from app.monitoring.usecase import run_monitoring_for_user
from app.notify.email_smtp import build_alert_html, send_email

router = APIRouter()


def _get_alert_config(session, user_id: int) -> AlertConfig | None:
    return session.query(AlertConfig).filter_by(user_id=user_id).first()


def _save_run(session, user_id: int, result, run_type: str) -> MonitoringRun:
    run = MonitoringRun(
        user_id=user_id,
        run_type=run_type,
        total_fetched=result.total_fetched,
        keyword_matched=result.keyword_matched,
        new_items=result.new_items,
        notified=len(result.notices),
        status="completed" if not result.errors else "partial",
        error_detail="; ".join(result.errors) if result.errors else None,
    )
    session.add(run)
    session.flush()

    for notice in result.notices:
        session.add(FoundNotice(
            run_id=run.id,
            source=notice.source,
            source_item_id=notice.source_item_id,
            title=notice.title,
            agency=notice.agency,
            url=notice.url,
            matched_keywords=",".join(sorted(notice.matched_keywords)),
            published_at=notice.published_at,
        ))

    return run


@router.post("/test-email", response_model=None)
def test_email(request: Request) -> HTMLResponse | RedirectResponse:
    auth = require_auth(request)
    if isinstance(auth, RedirectResponse):
        return auth
    user: User = auth

    settings = request.app.state.settings
    templates = request.app.state.templates
    session_factory = get_session_factory(request.app.state.engine)

    with session_factory() as session:
        config = _get_alert_config(session, user.id)
        since_hours = config.since_hours if config else 24
        recipients_str = config.recipients if config else user.email
        enabled_sources_str = config.enabled_sources if config else "kstartup,g2b_bid"
        enabled_sources = enabled_sources_str.split(",") if config else None

        source_configs = load_enabled_configs(settings.config_path, enabled_sources)

        result = run_monitoring_for_user(
            user_id=user.id,
            source_configs=source_configs,
            since_hours=since_hours,
            session=session,
        )

        _save_run(session, user.id, result, "test")
        session.commit()

    if result.notices:
        html_body = build_alert_html(result.notices)
        try:
            send_email(
                smtp_host=settings.smtp_host,
                smtp_port=settings.smtp_port,
                smtp_user=settings.smtp_user,
                smtp_password=settings.smtp_pass,
                from_addr=settings.smtp_user,
                to_addrs=[user.email],
                subject=f"[테스트] 모빌리티 공고 알림 ({result.new_items}건)",
                html=html_body,
            )
        except RuntimeError:
            pass

    return templates.TemplateResponse(
        request,
        "dashboard.html",
        {
            "user": user,
            "recipients": recipients_str,
            "since_hours": since_hours,
            "enabled_sources": enabled_sources_str,
            "info": f"Test email sent to {user.email} ({result.new_items} new items)",
        },
    )


@router.post("/run", response_model=None)
def run_monitoring(request: Request) -> RedirectResponse:
    auth = require_auth(request)
    if isinstance(auth, RedirectResponse):
        return auth
    user: User = auth

    settings = request.app.state.settings
    session_factory = get_session_factory(request.app.state.engine)

    with session_factory() as session:
        config = _get_alert_config(session, user.id)
        if not config:
            return RedirectResponse("/dashboard", status_code=303)

        recipients = [r.strip() for r in config.recipients.split(",") if r.strip()]
        if len(recipients) > 10:
            return RedirectResponse("/dashboard", status_code=303)

        enabled_sources = config.enabled_sources.split(",") if config.enabled_sources else None
        source_configs = load_enabled_configs(settings.config_path, enabled_sources)

        result = run_monitoring_for_user(
            user_id=user.id,
            source_configs=source_configs,
            since_hours=config.since_hours,
            session=session,
        )

        _save_run(session, user.id, result, "full")
        session.commit()

    if result.notices and recipients:
        html_body = build_alert_html(result.notices)
        try:
            send_email(
                smtp_host=settings.smtp_host,
                smtp_port=settings.smtp_port,
                smtp_user=settings.smtp_user,
                smtp_password=settings.smtp_pass,
                from_addr=settings.smtp_user,
                to_addrs=recipients,
                subject=f"[모빌리티 공고 모니터] {result.new_items}건 신규 공고",
                html=html_body,
            )
        except RuntimeError:
            pass

    return RedirectResponse("/results", status_code=303)


@router.get("/results", response_model=None)
def results(request: Request) -> HTMLResponse | RedirectResponse:
    auth = require_auth(request)
    if isinstance(auth, RedirectResponse):
        return auth
    user: User = auth

    templates = request.app.state.templates
    session_factory = get_session_factory(request.app.state.engine)

    with session_factory() as session:
        runs = (
            session.query(MonitoringRun)
            .filter_by(user_id=user.id)
            .order_by(MonitoringRun.created_at.desc())
            .limit(20)
            .all()
        )

        run_data = []
        for run in runs:
            notices = (
                session.query(FoundNotice)
                .filter_by(run_id=run.id)
                .all()
            )
            run_data.append({"run": run, "notices": notices})

    return templates.TemplateResponse(
        request,
        "results.html",
        {"user": user, "run_data": run_data},
    )
