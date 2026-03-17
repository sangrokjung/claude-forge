"""SQLite database engine and session management."""

from __future__ import annotations

from sqlalchemy import Engine, create_engine, event
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

_engines: dict[str, Engine] = {}
_session_factories: dict[str, sessionmaker[Session]] = {}


def _enable_wal(dbapi_conn, _connection_record) -> None:  # type: ignore[no-untyped-def]
    cursor = dbapi_conn.cursor()
    cursor.execute("PRAGMA journal_mode=WAL")
    cursor.close()


def get_engine(database_url: str) -> Engine:
    if database_url not in _engines:
        connect_args: dict = {}
        kwargs: dict = {}

        if database_url.startswith("sqlite"):
            connect_args["check_same_thread"] = False
            # In-memory SQLite needs StaticPool to share the connection
            if ":memory:" in database_url or database_url == "sqlite://":
                kwargs["poolclass"] = StaticPool

        engine = create_engine(database_url, connect_args=connect_args, **kwargs)

        # WAL mode only for file-based SQLite
        if database_url.startswith("sqlite") and ":memory:" not in database_url and database_url != "sqlite://":
            event.listen(engine, "connect", _enable_wal)

        _engines[database_url] = engine
    return _engines[database_url]


def get_session_factory(engine: Engine) -> sessionmaker[Session]:
    key = str(engine.url)
    if key not in _session_factories:
        _session_factories[key] = sessionmaker(bind=engine)
    return _session_factories[key]


def create_tables(engine: Engine) -> None:
    from app.models import Base

    Base.metadata.create_all(engine)
