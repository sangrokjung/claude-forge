"""SQLAlchemy ORM models."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    email: Mapped[str] = mapped_column(String(320), unique=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(128), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    alert_config: Mapped[AlertConfig | None] = relationship(back_populates="user", uselist=False)
    monitoring_runs: Mapped[list[MonitoringRun]] = relationship(back_populates="user")


class AlertConfig(Base):
    __tablename__ = "alert_configs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    recipients: Mapped[str] = mapped_column(Text, nullable=False, default="")
    since_hours: Mapped[int] = mapped_column(Integer, nullable=False, default=24)
    enabled_sources: Mapped[str] = mapped_column(Text, nullable=False, default="kstartup,g2b_bid")
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow, onupdate=_utcnow)

    user: Mapped[User] = relationship(back_populates="alert_config")


class MonitoringRun(Base):
    __tablename__ = "monitoring_runs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    run_type: Mapped[str] = mapped_column(String(10), nullable=False)
    total_fetched: Mapped[int] = mapped_column(Integer, default=0)
    keyword_matched: Mapped[int] = mapped_column(Integer, default=0)
    new_items: Mapped[int] = mapped_column(Integer, default=0)
    notified: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    error_detail: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)

    user: Mapped[User] = relationship(back_populates="monitoring_runs")
    found_notices: Mapped[list[FoundNotice]] = relationship(back_populates="run")


class FoundNotice(Base):
    __tablename__ = "found_notices"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    run_id: Mapped[int] = mapped_column(Integer, ForeignKey("monitoring_runs.id"), nullable=False)
    source: Mapped[str] = mapped_column(String(50), nullable=False)
    source_item_id: Mapped[str] = mapped_column(String(200), nullable=False)
    title: Mapped[str] = mapped_column(Text, nullable=False)
    agency: Mapped[str] = mapped_column(String(200), nullable=False, default="")
    url: Mapped[str] = mapped_column(Text, nullable=False, default="")
    matched_keywords: Mapped[str] = mapped_column(Text, nullable=False, default="")
    published_at: Mapped[str] = mapped_column(String(50), nullable=False, default="")

    run: Mapped[MonitoringRun] = relationship(back_populates="found_notices")


class SeenNotice(Base):
    __tablename__ = "seen_notices"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    source_item_uid: Mapped[str] = mapped_column(String(300), nullable=False)
    first_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=_utcnow)
