#!/usr/bin/env python3
"""
storage.py - 시장조사 데이터 JSONL 저장·스냅샷·가격 이력 관리

사용법:
    from storage import Storage
    store = Storage("data")
    store.save(products)           # products.jsonl에 추가
    store.snapshot()               # data/snapshots/YYYY-MM-DD/ 저장
    prior = store.load_prior()     # 이전 스냅샷 로드 (가격 이력용)
"""

import json
import os
from dataclasses import asdict
from datetime import datetime, date
from pathlib import Path
from typing import Any


class Storage:
    def __init__(self, data_dir: str = "data"):
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(parents=True, exist_ok=True)
        self.products_file = self.data_dir / "products.jsonl"
        self.snapshots_dir = self.data_dir / "snapshots"
        self.reports_dir = self.data_dir / "reports"
        self.reports_dir.mkdir(parents=True, exist_ok=True)

    # ── 저장 ──────────────────────────────────────────────────────────

    def save(self, products: list) -> int:
        """ProductSnapshot 목록을 products.jsonl에 추가 저장. 저장 수 반환."""
        count = 0
        with open(self.products_file, "a", encoding="utf-8") as f:
            for p in products:
                record = asdict(p) if hasattr(p, "__dataclass_fields__") else p
                record = _serialize(record)
                f.write(json.dumps(record, ensure_ascii=False) + "\n")
                count += 1
        return count

    def overwrite(self, products: list) -> int:
        """products.jsonl 전체를 덮어씀 (중복 제거 후 재저장 시 사용)."""
        count = 0
        with open(self.products_file, "w", encoding="utf-8") as f:
            for p in products:
                record = asdict(p) if hasattr(p, "__dataclass_fields__") else p
                record = _serialize(record)
                f.write(json.dumps(record, ensure_ascii=False) + "\n")
                count += 1
        return count

    # ── 로드 ──────────────────────────────────────────────────────────

    def load_all(self) -> list[dict]:
        """products.jsonl 전체를 dict 목록으로 반환."""
        if not self.products_file.exists():
            return []
        records = []
        with open(self.products_file, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    records.append(json.loads(line))
        return records

    def load_by_type(self, product_type: str) -> list[dict]:
        """특정 product_type 상품만 필터링하여 반환."""
        return [r for r in self.load_all() if r.get("product_type") == product_type]

    def load_by_platform(self, platform: str) -> list[dict]:
        """특정 플랫폼 상품만 필터링하여 반환."""
        return [r for r in self.load_all() if r.get("platform") == platform]

    # ── 스냅샷 ────────────────────────────────────────────────────────

    def snapshot(self, snapshot_date: date | None = None) -> Path:
        """현재 products.jsonl을 날짜별 스냅샷으로 복사 저장."""
        today = snapshot_date or date.today()
        snap_dir = self.snapshots_dir / str(today)
        snap_dir.mkdir(parents=True, exist_ok=True)
        snap_file = snap_dir / "products.jsonl"
        if self.products_file.exists():
            snap_file.write_bytes(self.products_file.read_bytes())
        return snap_file

    def load_prior_snapshot(self, days_back: int = 1) -> list[dict]:
        """days_back일 전 스냅샷을 로드. 없으면 빈 목록 반환."""
        from datetime import timedelta
        target_date = date.today() - timedelta(days=days_back)
        snap_file = self.snapshots_dir / str(target_date) / "products.jsonl"
        if not snap_file.exists():
            return []
        records = []
        with open(snap_file, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line:
                    records.append(json.loads(line))
        return records

    def list_snapshots(self) -> list[str]:
        """저장된 스냅샷 날짜 목록 반환 (최신순)."""
        if not self.snapshots_dir.exists():
            return []
        dates = sorted(
            [d.name for d in self.snapshots_dir.iterdir() if d.is_dir()],
            reverse=True,
        )
        return dates

    # ── 가격 이력 병합 ─────────────────────────────────────────────────

    def merge_price_history(
        self, current_records: list[dict], prior_records: list[dict]
    ) -> list[dict]:
        """
        현재 수집 데이터와 이전 스냅샷을 비교하여 price_history를 업데이트.
        product_id + platform 조합으로 매칭.
        """
        prior_map: dict[str, dict] = {}
        for r in prior_records:
            key = f"{r.get('platform')}::{r.get('product_id')}"
            prior_map[key] = r

        updated = []
        for record in current_records:
            key = f"{record.get('platform')}::{record.get('product_id')}"
            prior = prior_map.get(key)
            if prior:
                history = list(prior.get("price_history") or [])
                prior_price = prior.get("sale_price")
                prior_date = prior.get("scraped_at", "")[:10]  # YYYY-MM-DD
                if prior_price and prior_date:
                    # 중복 날짜 제외
                    if not any(h.get("date") == prior_date for h in history):
                        history.append({"date": prior_date, "price": prior_price})
                # 최근 30개만 유지
                history = sorted(history, key=lambda h: h["date"])[-30:]
                record["price_history"] = history
            updated.append(record)
        return updated

    # ── 통계 ──────────────────────────────────────────────────────────

    def stats(self) -> dict:
        """저장된 데이터의 간단한 통계 반환."""
        records = self.load_all()
        if not records:
            return {"total": 0}

        platforms: dict[str, int] = {}
        types: dict[str, int] = {}
        for r in records:
            p = r.get("platform", "unknown")
            t = r.get("product_type", "unknown")
            platforms[p] = platforms.get(p, 0) + 1
            types[t] = types.get(t, 0) + 1

        return {
            "total": len(records),
            "by_platform": platforms,
            "by_type": types,
            "snapshots": self.list_snapshots(),
        }


# ── 유틸리티 ──────────────────────────────────────────────────────────

def _serialize(obj: Any) -> Any:
    """datetime 등 JSON 직렬화 불가 타입 변환."""
    if isinstance(obj, datetime):
        return obj.isoformat()
    if isinstance(obj, date):
        return str(obj)
    if isinstance(obj, dict):
        return {k: _serialize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_serialize(v) for v in obj]
    return obj


# ── CLI ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="시장조사 데이터 저장소 관리")
    parser.add_argument("--data-dir", default="data", help="데이터 디렉터리 경로")
    parser.add_argument("--stats", action="store_true", help="저장 통계 출력")
    parser.add_argument("--snapshot", action="store_true", help="현재 데이터 스냅샷 생성")
    parser.add_argument("--list-snapshots", action="store_true", help="스냅샷 목록 출력")
    args = parser.parse_args()

    store = Storage(args.data_dir)

    if args.stats:
        stats = store.stats()
        print(json.dumps(stats, ensure_ascii=False, indent=2))
    elif args.snapshot:
        path = store.snapshot()
        print(f"스냅샷 저장: {path}")
    elif args.list_snapshots:
        for d in store.list_snapshots():
            print(d)
    else:
        parser.print_help()
