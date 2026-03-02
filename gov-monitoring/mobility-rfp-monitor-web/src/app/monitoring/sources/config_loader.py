"""Load source configs from YAML."""

from __future__ import annotations

from pathlib import Path

import yaml

from app.monitoring.sources.base import SourceConfig


def load_source_configs(config_path: str | Path) -> list[SourceConfig]:
    path = Path(config_path)
    if not path.exists():
        return []

    with open(path, encoding="utf-8") as f:
        raw = yaml.safe_load(f)

    if not raw or "sources" not in raw:
        return []

    configs: list[SourceConfig] = []
    for name, data in raw["sources"].items():
        configs.append(SourceConfig(name=name, **data))

    return configs


def load_enabled_configs(
    config_path: str | Path,
    enabled_names: list[str] | None = None,
) -> list[SourceConfig]:
    all_configs = load_source_configs(config_path)
    result = [c for c in all_configs if c.enabled]
    if enabled_names is not None:
        result = [c for c in result if c.name in enabled_names]
    return result
