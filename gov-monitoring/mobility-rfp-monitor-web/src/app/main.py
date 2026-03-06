"""FastAPI application factory."""

from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates

from app.settings import Settings


def create_app(settings: Settings | None = None) -> FastAPI:
    if settings is None:
        settings = Settings()  # type: ignore[call-arg]

    application = FastAPI(title="Mobility RFP Monitor")
    application.state.settings = settings

    templates_dir = Path(__file__).parent / "templates"
    templates = Jinja2Templates(directory=str(templates_dir))
    application.state.templates = templates

    from app.db import create_tables, get_engine

    engine = get_engine(settings.database_url)
    create_tables(engine)
    application.state.engine = engine

    from app.routes.auth_routes import router as auth_router
    from app.routes.dashboard_routes import router as dashboard_router
    from app.routes.monitoring_routes import router as monitoring_router

    application.include_router(auth_router)
    application.include_router(dashboard_router)
    application.include_router(monitoring_router)

    @application.get("/", response_class=HTMLResponse)
    def index(request: Request) -> HTMLResponse:
        return templates.TemplateResponse(request, "index.html")

    return application


def _create_production_app() -> FastAPI:
    """Called by uvicorn: `uvicorn app.main:app`."""
    return create_app()


# Only create module-level app when JWT_SECRET_KEY is available (production).
# During tests, create_app() is called explicitly with test settings.
if os.environ.get("JWT_SECRET_KEY"):
    app = _create_production_app()
