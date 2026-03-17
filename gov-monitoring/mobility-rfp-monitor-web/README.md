# Mobility RFP Monitor Web

Korean government mobility RFP monitoring web service. Tracks K-Startup and KONEPS (G2B) procurement notices related to mobility, autonomous driving, EV, and smart transportation.

## Features

- User registration and JWT cookie-based authentication
- Alert configuration (recipients, lookup window, enabled sources)
- Config-driven source adapters (YAML-based API endpoint/field mapping)
- 120+ mobility keyword matching with regex engine
- SQLite-based deduplication per user
- Test email (to yourself) and full monitoring run (to all recipients)
- Monitoring run history and results viewer

## Quick Start

```bash
# Install dependencies
uv sync

# Run tests
uv run pytest tests/ -v

# Start dev server
JWT_SECRET_KEY=dev-secret DATA_GO_KR_API_KEY=your-key uv run uvicorn app.main:_create_production_app --factory --reload --app-dir src
```

## Configuration

Copy `config.example.yaml` to `config.yaml` and adjust source settings.

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `JWT_SECRET_KEY` | Yes | Secret key for JWT token signing |
| `DATA_GO_KR_API_KEY` | Yes | data.go.kr API service key |
| `DATABASE_URL` | No | SQLite URL (default: `sqlite:///./rfp_monitor.db`) |
| `SMTP_HOST` | No | SMTP server (default: `smtp.gmail.com`) |
| `SMTP_PORT` | No | SMTP port (default: `587`) |
| `SMTP_USER` | No | SMTP username |
| `SMTP_PASS` | No | SMTP password (Gmail app password) |

## Architecture

```
src/app/
  main.py              # FastAPI app factory
  settings.py          # pydantic-settings
  db.py                # SQLite engine + session
  models.py            # User, AlertConfig, MonitoringRun, FoundNotice, SeenNotice
  auth/                # JWT cookie auth + bcrypt password
  routes/              # auth, dashboard, monitoring routes
  monitoring/
    dto.py             # NormalizedNotice (frozen dataclass)
    keywords.py        # 120+ mobility keywords + regex
    filter.py          # Keyword filter pipeline
    dedupe.py          # SQLite-based deduplication
    usecase.py         # Monitoring orchestrator
    sources/
      base.py          # SourceConfig, FieldMappingEntry
      config_loader.py # YAML -> SourceConfig
      generic_client.py # Config-driven API client
  notify/
    email_smtp.py      # HTML builder + SMTP sender
  templates/           # Jinja2 SSR templates
```

### Config-Driven Source Adapters

API endpoints, parameters, and field mappings are defined in `config.yaml`, not in code. To add a new data source, add a YAML block — no Python changes needed.

## Tech Stack

FastAPI + Jinja2 SSR | SQLite + SQLAlchemy | JWT HttpOnly Cookie | bcrypt | httpx | PyYAML
