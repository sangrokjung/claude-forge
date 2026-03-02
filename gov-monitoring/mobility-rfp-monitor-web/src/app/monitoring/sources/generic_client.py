"""Config-driven generic source client."""

from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone

import httpx

from app.monitoring.dto import NormalizedNotice
from app.monitoring.sources.base import FieldMappingEntry, SourceConfig
from app.monitoring.sources.http_client import fetch_json


def resolve_field(raw: dict, candidates: list[str]) -> str:
    """Try candidate field names in order, return first non-empty value."""
    for key in candidates:
        val = raw.get(key)
        if val is not None and str(val).strip():
            return str(val).strip()
    return ""


def resolve_composite_id(raw: dict, template: str) -> str:
    """Build composite ID from template like '{bidNtceNo}-{bidNtceOrd}'."""
    result = template
    for key in raw:
        placeholder = "{" + key + "}"
        if placeholder in result:
            result = result.replace(placeholder, str(raw.get(key, "")))
    return result


def extract_items(response_json: dict, data_path: str) -> list[dict]:
    """Extract items from response using dot-path like 'response.body.items'."""
    current = response_json
    for part in data_path.split("."):
        if isinstance(current, dict):
            current = current.get(part, [])
        else:
            return []
    if isinstance(current, list):
        return current
    if isinstance(current, dict):
        return [current]
    return []


def _resolve_mapping(
    raw: dict,
    field_name: str,
    mapping: dict[str, FieldMappingEntry],
) -> str:
    entry = mapping.get(field_name)
    if entry is None:
        return ""
    if entry.composite:
        return resolve_composite_id(raw, entry.composite)
    return resolve_field(raw, entry.candidates)


def normalize_item(raw: dict, config: SourceConfig, fetched_at: str) -> NormalizedNotice:
    """Normalize a single raw API item into NormalizedNotice using config mapping."""
    mapping = config.field_mapping

    item_id = _resolve_mapping(raw, "item_id", mapping)
    if not item_id:
        item_id = _resolve_mapping(raw, "title", mapping)

    return NormalizedNotice(
        source=config.name,
        source_item_id=item_id,
        title=_resolve_mapping(raw, "title", mapping),
        agency=_resolve_mapping(raw, "agency", mapping),
        summary=_resolve_mapping(raw, "summary", mapping),
        url=_resolve_mapping(raw, "url", mapping),
        deadline=_resolve_mapping(raw, "deadline", mapping),
        published_at=_resolve_mapping(raw, "published_at", mapping),
        fetched_at=fetched_at,
        raw=raw,
    )


def _build_params(config: SourceConfig, since_hours: int) -> dict:
    params = dict(config.params)

    api_key = os.environ.get(config.service_key_env, "")
    if api_key:
        params[config.service_key_param] = api_key

    if config.date_params:
        now = datetime.now(timezone.utc)
        since = now - timedelta(hours=since_hours)
        params[config.date_params.since_param] = since.strftime(config.date_params.format)
        params[config.date_params.until_param] = now.strftime(config.date_params.format)

    return params


def build_url(config: SourceConfig) -> str:
    base = config.base_url.rstrip("/")
    path = config.path.lstrip("/")
    return f"{base}/{path}"


class GenericSourceClient:
    """Config-driven source client that works for any API source."""

    def __init__(self, config: SourceConfig, http_client: httpx.Client | None = None) -> None:
        self._config = config
        self._http = http_client or httpx.Client(timeout=20.0)

    def fetch(self, *, since_hours: int = 24) -> list[NormalizedNotice]:
        url = build_url(self._config)
        params = _build_params(self._config, since_hours)
        fetched_at = datetime.now(timezone.utc).isoformat()

        response_json = fetch_json(self._http, url, method=self._config.method, params=params)
        items = extract_items(response_json, self._config.response_data_path)

        return [normalize_item(raw, self._config, fetched_at) for raw in items]
