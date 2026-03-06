"""Source client protocol and config models."""

from __future__ import annotations

from typing import Protocol

from pydantic import BaseModel

from app.monitoring.dto import NormalizedNotice


class FieldMappingEntry(BaseModel, frozen=True):
    candidates: list[str]
    composite: str | None = None


class DateParamConfig(BaseModel, frozen=True):
    since_param: str
    until_param: str
    format: str = "%Y%m%d%H%M"


class SourceConfig(BaseModel, frozen=True):
    name: str
    enabled: bool = True
    base_url: str
    path: str
    method: str = "GET"
    service_key_env: str
    service_key_param: str = "serviceKey"
    params: dict[str, str | int] = {}
    date_params: DateParamConfig | None = None
    response_data_path: str
    field_mapping: dict[str, FieldMappingEntry]


class SourceClient(Protocol):
    def fetch(self, *, since_hours: int) -> list[NormalizedNotice]: ...
