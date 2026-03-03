#!/usr/bin/env python3
"""
analyzer.py - 수집 데이터 분석·정규화·경쟁 지표 계산

주요 기능:
  - 단위 가격(unit_price) 보정 및 검증
  - 가격대 구간(price_tier) 분류: 저가/중가/고가
  - 가격·평점 백분위 계산
  - 리뷰 텍스트에서 긍정/부정 키워드 추출
  - CategoryTrendReport 집계 생성

사용법:
    python3 analyzer.py --input data/products.jsonl --output data/analyzed.jsonl
    python3 analyzer.py --input data/products.jsonl --trend --product-type 위생장갑
"""

import argparse
import json
import re
import sys
from collections import Counter
from dataclasses import dataclass, field, asdict
from datetime import datetime
from pathlib import Path
from typing import Optional


# ── 긍정/부정 키워드 사전 ─────────────────────────────────────────────

POSITIVE_SEED = [
    '좋아요', '좋습니다', '만족', '추천', '훌륭', '완벽', '최고',
    '깔끔', '편리', '실용', '튼튼', '두껍', '찢어지지', '방수',
    '무분말', '냄새없', '식품', '안전', '인증', '무독성',
    '빠른배송', '당일', '새벽', '포장', '깨끗',
]

NEGATIVE_SEED = [
    '별로', '실망', '불만', '최악', '쓰레기', '환불', '반품',
    '찢어짐', '구멍', '불량', '냄새', '유해', '미끄러', '작아요',
    '느린배송', '배송지연', '파손', '오배송', '품질저하',
    '얇아요', '얇다', '금방', '소량',
]

COMPLAINT_PATTERNS = {
    '배송': ['배송', '배달', '택배', '지연', '늦'],
    '품질': ['품질', '불량', '찢어', '구멍', '파손', '두께'],
    '포장': ['포장', '박스', '봉지', '비닐'],
    '사이즈': ['사이즈', '크기', '작아', '커요', '길이'],
    '냄새': ['냄새', '악취', '화학'],
    '수량': ['수량', '개수', '적어', '부족'],
}


# ── 집계 트렌드 레포트 ────────────────────────────────────────────────

@dataclass
class CategoryTrendReport:
    """카테고리/키워드 단위 집계 지표 (Category J 필드)."""
    product_type: str
    search_keyword: str
    platform: str
    data_collection_period: dict = field(default_factory=dict)  # {start, end}
    total_products_collected: int = 0

    # 가격 통계
    category_avg_price: int = 0
    category_median_price: int = 0
    category_price_range: dict = field(default_factory=dict)   # {min, max, p25, p75}
    category_avg_discount_rate: float = 0.0

    # 평점
    category_avg_rating: float = 0.0

    # 배송
    free_shipping_ratio: float = 0.0
    rocket_delivery_ratio: float = 0.0

    # 시장 구조
    top_brand_market_share: dict = field(default_factory=dict)  # {brand: share}
    price_tier_distribution: dict = field(default_factory=dict) # {저가:n, 중가:n, 고가:n}
    sponsored_ratio: float = 0.0
    keyword_competitor_count: int = 0

    # 집계 메타
    generated_at: str = ""


# ── 핵심 분석 함수 ────────────────────────────────────────────────────

def compute_unit_price(record: dict) -> dict:
    """단위 가격 재계산 (이미 있으면 유지, 없으면 상품명에서 수량 추출)."""
    if record.get('unit_price'):
        return record

    sale_price = record.get('sale_price', 0)
    if not sale_price:
        return record

    product_name = record.get('product_name', '')
    product_type = record.get('product_type', '')

    # 스펙 필드에서 수량 우선 사용
    qty = (record.get('glove_qty_per_pack') or
           record.get('bag_qty_per_pack'))

    if not qty:
        # 상품명에서 수량 추출
        patterns = [
            (r'(\d+)\s*매', '매당'),
            (r'(\d+)\s*장', '장당'),
            (r'(\d+)\s*개', '개당'),
            (r'(\d+)\s*쌍', '쌍당'),
            (r'(\d+)\s*p\b', '개당'),
            (r'(\d+)\s*PCS', '개당'),
        ]
        for pat, basis_label in patterns:
            m = re.search(pat, product_name, re.IGNORECASE)
            if m:
                qty_found = int(m.group(1))
                if 1 < qty_found <= 10000:
                    record['unit_price'] = round(sale_price / qty_found, 2)
                    record['unit_price_basis'] = basis_label
                    return record
    elif qty > 1:
        basis_map = {
            '위생장갑': '장당',
            '위생백': '매당',
            '지퍼백': '매당',
            '위생용품세트': '개당',
        }
        record['unit_price'] = round(sale_price / qty, 2)
        record['unit_price_basis'] = basis_map.get(product_type, '개당')

    return record


def classify_price_tier(
    sale_price: int,
    p33: float,
    p67: float,
) -> str:
    """가격대 구간 분류."""
    if sale_price <= p33:
        return '저가'
    if sale_price <= p67:
        return '중가'
    return '고가'


def compute_percentiles(records: list[dict], field: str) -> dict[str, float]:
    """특정 필드의 백분위 매핑 반환 {product_id: percentile}."""
    values = [(r.get('product_id', ''), r.get(field, 0) or 0) for r in records]
    sorted_vals = sorted(values, key=lambda x: x[1])
    n = len(sorted_vals)
    result = {}
    for rank, (pid, _) in enumerate(sorted_vals):
        result[pid] = round((rank / max(n - 1, 1)) * 100, 1) if n > 1 else 50.0
    return result


def extract_review_keywords(
    review_samples: list[dict],
    product_name: str = '',
) -> tuple[list[str], list[str], list[str]]:
    """
    리뷰 샘플 텍스트에서 긍정/부정 키워드 및 불만 카테고리 추출.
    Returns: (positive_keywords, negative_keywords, complaint_categories)
    """
    all_text = ' '.join(r.get('text', '') for r in review_samples)
    all_text += ' ' + product_name

    pos_counter: Counter = Counter()
    neg_counter: Counter = Counter()
    complaints: set = set()

    for word in POSITIVE_SEED:
        if word in all_text:
            pos_counter[word] += all_text.count(word)

    for word in NEGATIVE_SEED:
        if word in all_text:
            neg_counter[word] += all_text.count(word)

    for category, patterns in COMPLAINT_PATTERNS.items():
        if any(p in all_text for p in patterns):
            complaints.add(category)

    top_pos = [w for w, _ in pos_counter.most_common(10)]
    top_neg = [w for w, _ in neg_counter.most_common(10)]
    return top_pos, top_neg, sorted(complaints)


def enrich_records(records: list[dict]) -> list[dict]:
    """
    수집 데이터 일괄 보정:
    1. unit_price 계산
    2. price_tier 분류
    3. 가격·평점 백분위 계산
    4. 리뷰 키워드 추출
    """
    # 단위 가격 보정
    records = [compute_unit_price(r) for r in records]

    # 품목+플랫폼 그룹별 처리
    groups: dict[str, list[dict]] = {}
    for r in records:
        key = f"{r.get('product_type', 'unknown')}::{r.get('platform', 'unknown')}"
        groups.setdefault(key, []).append(r)

    enriched = []
    for key, group in groups.items():
        prices = sorted([r.get('sale_price', 0) for r in group if r.get('sale_price', 0) > 0])
        n = len(prices)

        if n >= 3:
            p33 = prices[n // 3]
            p67 = prices[(n * 2) // 3]
            p25 = prices[n // 4]
            p75 = prices[(n * 3) // 4]
        else:
            p33 = p67 = prices[n // 2] if prices else 0
            p25 = prices[0] if prices else 0
            p75 = prices[-1] if prices else 0

        # 가격 백분위 맵
        price_pct_map = compute_percentiles(group, 'sale_price')
        rating_pct_map = compute_percentiles(group, 'review_rating_avg')

        for r in group:
            pid = r.get('product_id', '')

            # 가격대 구간
            sp = r.get('sale_price', 0)
            if sp:
                r['price_tier'] = classify_price_tier(sp, p33, p67)
            r['price_percentile'] = price_pct_map.get(pid)
            r['rating_percentile'] = rating_pct_map.get(pid)

            # 리뷰 키워드
            if r.get('review_samples') and not r.get('positive_keywords'):
                pos, neg, complaints = extract_review_keywords(
                    r['review_samples'], r.get('product_name', '')
                )
                r['positive_keywords'] = pos
                r['negative_keywords'] = neg
                r['complaint_categories'] = complaints

            enriched.append(r)

    return enriched


def build_trend_report(
    records: list[dict],
    product_type: str,
    platform: str,
    search_keyword: str = '',
) -> CategoryTrendReport:
    """Category J 집계 트렌드 리포트 생성."""
    subset = [
        r for r in records
        if r.get('product_type') == product_type and r.get('platform') == platform
    ]
    if not subset:
        return CategoryTrendReport(
            product_type=product_type,
            search_keyword=search_keyword,
            platform=platform,
            generated_at=datetime.now().isoformat(),
        )

    prices = [r['sale_price'] for r in subset if r.get('sale_price', 0) > 0]
    ratings = [r['review_rating_avg'] for r in subset if r.get('review_rating_avg', 0) > 0]
    discount_rates = [r['discount_rate'] for r in subset if r.get('discount_rate', 0) > 0]

    def percentile(data: list, pct: float) -> float:
        if not data:
            return 0.0
        sorted_data = sorted(data)
        idx = int(len(sorted_data) * pct / 100)
        return sorted_data[min(idx, len(sorted_data) - 1)]

    # 브랜드 점유율
    brand_counts: Counter = Counter(
        r.get('brand_name', '미분류') for r in subset if r.get('brand_name')
    )
    total_brands = sum(brand_counts.values()) or 1
    top_brands = {
        b: round(c / total_brands, 3)
        for b, c in brand_counts.most_common(10)
    }

    # 가격대 분포
    tier_dist: Counter = Counter(r.get('price_tier', '미분류') for r in subset)

    # 날짜 범위
    dates = sorted(r.get('scraped_at', '')[:10] for r in subset if r.get('scraped_at'))

    report = CategoryTrendReport(
        product_type=product_type,
        search_keyword=search_keyword,
        platform=platform,
        data_collection_period={
            'start': dates[0] if dates else '',
            'end': dates[-1] if dates else '',
        },
        total_products_collected=len(subset),
        category_avg_price=int(sum(prices) / len(prices)) if prices else 0,
        category_median_price=int(percentile(prices, 50)),
        category_price_range={
            'min': min(prices) if prices else 0,
            'max': max(prices) if prices else 0,
            'p25': int(percentile(prices, 25)),
            'p75': int(percentile(prices, 75)),
        },
        category_avg_discount_rate=round(
            sum(discount_rates) / len(discount_rates), 3
        ) if discount_rates else 0.0,
        category_avg_rating=round(
            sum(ratings) / len(ratings), 2
        ) if ratings else 0.0,
        free_shipping_ratio=round(
            sum(1 for r in subset if r.get('is_free_shipping')) / len(subset), 3
        ),
        rocket_delivery_ratio=round(
            sum(1 for r in subset if r.get('is_rocket_delivery')) / len(subset), 3
        ),
        top_brand_market_share=top_brands,
        price_tier_distribution=dict(tier_dist),
        sponsored_ratio=round(
            sum(1 for r in subset if r.get('is_sponsored')) / len(subset), 3
        ),
        generated_at=datetime.now().isoformat(),
    )
    return report


# ── CLI ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="시장조사 데이터 분석기")
    parser.add_argument("--input", default="data/products.jsonl", help="입력 JSONL 경로")
    parser.add_argument("--output", default="data/analyzed.jsonl", help="출력 JSONL 경로")
    parser.add_argument("--trend", action="store_true", help="트렌드 리포트 출력")
    parser.add_argument("--product-type", help="필터: 위생장갑 / 위생백 / 지퍼백 / 위생용품세트")
    parser.add_argument("--platform", default="coupang", help="필터: coupang / naver")
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        print(f"[error] 파일 없음: {input_path}", file=sys.stderr)
        sys.exit(1)

    records = []
    with open(input_path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line:
                records.append(json.loads(line))

    print(f"[info] {len(records)}개 레코드 로드", file=sys.stderr)

    enriched = enrich_records(records)

    if args.trend:
        product_types = (
            [args.product_type] if args.product_type
            else ['위생장갑', '위생백', '지퍼백', '위생용품세트']
        )
        platforms = [args.platform]
        reports = []
        for pt in product_types:
            for pl in platforms:
                report = build_trend_report(enriched, pt, pl)
                reports.append(asdict(report))
        print(json.dumps(reports, ensure_ascii=False, indent=2))
    else:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with open(output_path, 'w', encoding='utf-8') as f:
            for r in enriched:
                f.write(json.dumps(r, ensure_ascii=False) + '\n')
        print(f"[done] {len(enriched)}개 레코드 저장: {output_path}", file=sys.stderr)
