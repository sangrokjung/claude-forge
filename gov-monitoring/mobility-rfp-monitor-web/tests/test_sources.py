"""Phase 4: Source adapter tests."""

from __future__ import annotations

import json
from pathlib import Path

from app.monitoring.sources.base import FieldMappingEntry, SourceConfig
from app.monitoring.sources.config_loader import load_source_configs
from app.monitoring.sources.generic_client import (
    build_url,
    extract_items,
    normalize_item,
    resolve_composite_id,
    resolve_field,
)

FIXTURES = Path(__file__).parent / "fixtures"


def test_resolve_field_tries_candidates():
    raw = {"과제명": "자율주행 플랫폼", "title": ""}
    assert resolve_field(raw, ["title", "과제명"]) == "자율주행 플랫폼"


def test_resolve_field_returns_first_nonempty():
    raw = {"a": "", "b": "hello", "c": "world"}
    assert resolve_field(raw, ["a", "b", "c"]) == "hello"


def test_resolve_field_empty_when_none_match():
    raw = {"x": "value"}
    assert resolve_field(raw, ["a", "b"]) == ""


def test_resolve_composite_id():
    raw = {"bidNtceNo": "20260301001", "bidNtceOrd": "00"}
    result = resolve_composite_id(raw, "{bidNtceNo}-{bidNtceOrd}")
    assert result == "20260301001-00"


def test_extract_items_flat_path():
    data = {"data": [{"a": 1}, {"a": 2}]}
    items = extract_items(data, "data")
    assert len(items) == 2


def test_extract_items_nested_path():
    with open(FIXTURES / "g2b_bid_response.json", encoding="utf-8") as f:
        data = json.load(f)
    items = extract_items(data, "response.body.items")
    assert len(items) == 2


def test_config_loader_parses_yaml(settings):
    configs = load_source_configs(settings.config_path)
    assert len(configs) >= 2
    names = {c.name for c in configs}
    assert "kstartup" in names
    assert "g2b_bid" in names


def test_normalize_uses_config_candidates(mss_response_data):
    config = SourceConfig(
        name="kstartup",
        base_url="https://api.odcloud.kr/api/3044610/v1",
        path="uddi:test",
        service_key_env="DATA_GO_KR_API_KEY",
        response_data_path="data",
        field_mapping={
            "title": FieldMappingEntry(candidates=["공고명", "title"]),
            "summary": FieldMappingEntry(candidates=["과제명"]),
            "agency": FieldMappingEntry(candidates=["전문기관명"]),
            "published_at": FieldMappingEntry(candidates=["사업년도"]),
            "item_id": FieldMappingEntry(candidates=["과제명"], composite="{과제명}-{사업년도}"),
        },
    )
    raw = mss_response_data["data"][0]
    notice = normalize_item(raw, config, "2026-03-02T00:00:00")
    assert "자율주행" in notice.title
    assert notice.agency == "중소기업기술정보진흥원"
    assert notice.source_item_id == "자율주행 기반 스마트모빌리티 서비스 플랫폼-2025"


def test_normalize_fallback_field(g2b_bid_response_data):
    config = SourceConfig(
        name="g2b_bid",
        base_url="https://apis.data.go.kr/1230000/BidPublicInfoService",
        path="getBidPblancListInfoServc",
        service_key_env="DATA_GO_KR_API_KEY",
        response_data_path="response.body.items",
        field_mapping={
            "title": FieldMappingEntry(candidates=["bidNtceNm", "ntceNm"]),
            "agency": FieldMappingEntry(candidates=["ntceInsttNm"]),
            "url": FieldMappingEntry(candidates=["bidNtceDtlUrl", "ntceDtlUrl"]),
            "published_at": FieldMappingEntry(candidates=["bidNtceDt"]),
            "item_id": FieldMappingEntry(candidates=["bidNtceNo"], composite="{bidNtceNo}-{bidNtceOrd}"),
        },
    )
    raw = g2b_bid_response_data["response"]["body"]["items"][0]
    notice = normalize_item(raw, config, "2026-03-02T00:00:00")
    assert notice.title == "전기차 충전인프라 구축사업"
    assert notice.url == "https://g2b.go.kr/bid/20260301001"
    assert notice.source_item_id == "20260301001-00"


def test_config_change_updates_fetch_url():
    config1 = SourceConfig(
        name="test",
        base_url="https://api.example.com",
        path="v1/data",
        service_key_env="KEY",
        response_data_path="data",
        field_mapping={},
    )
    config2 = SourceConfig(
        name="test",
        base_url="https://api.example.com",
        path="v2/new-data",
        service_key_env="KEY",
        response_data_path="data",
        field_mapping={},
    )
    assert build_url(config1) == "https://api.example.com/v1/data"
    assert build_url(config2) == "https://api.example.com/v2/new-data"
