#!/usr/bin/env python3
"""
report_gen.py - 시장조사 보고서 생성 (CSV + Markdown)

사용법:
    python3 report_gen.py --input data/analyzed.jsonl --format csv --output data/reports/
    python3 report_gen.py --input data/analyzed.jsonl --format markdown --output data/reports/
    python3 report_gen.py --input data/analyzed.jsonl --format all --output data/reports/
    python3 report_gen.py --weekly  # 주간 시장 요약 리포트
"""

import argparse
import csv
import json
import sys
from datetime import datetime, date
from pathlib import Path


# ── CSV 출력 컬럼 정의 ────────────────────────────────────────────────
# 실무에서 가장 자주 조회하는 필드 순서로 정렬

CSV_COLUMNS = [
    # 기본 식별 정보
    ("플랫폼",              "platform"),
    ("상품유형",            "product_type"),
    ("검색키워드",          "search_keyword"),
    ("검색순위",            "search_rank"),
    ("광고여부",            "is_sponsored"),

    # 상품 정보
    ("상품명",              "product_name"),
    ("브랜드",              "brand_name"),
    ("제조사",              "manufacturer"),
    ("제조국",              "country_of_origin"),
    ("상품URL",             "product_url"),

    # 가격 정보 (핵심)
    ("정가",                "original_price"),
    ("판매가",              "sale_price"),
    ("할인율",              "discount_rate"),
    ("단위가격",            "unit_price"),
    ("단위기준",            "unit_price_basis"),
    ("쿠폰적용가",          "coupon_price"),
    ("최대할인가",          "max_discount_price"),
    ("가격대구간",          "price_tier"),
    ("가격백분위",          "price_percentile"),

    # 판매자 정보
    ("판매자명",            "seller_name"),
    ("판매자유형",          "seller_type"),
    ("판매자평점",          "seller_rating"),
    ("로켓배송",            "is_rocket_delivery"),
    ("공식브랜드스토어",    "is_brand_store"),

    # 스펙 (공통)
    ("장갑소재",            "glove_material"),
    ("장갑사이즈",          "glove_size"),
    ("장갑수량",            "glove_qty_per_pack"),
    ("분말여부",            "glove_has_powder"),
    ("백소재",              "bag_material"),
    ("백사이즈",            "bag_size"),
    ("백수량",              "bag_qty_per_pack"),
    ("지퍼유형",            "zipper_type"),
    ("냉동가능",            "freezer_safe"),
    ("전자레인지가능",      "microwave_safe"),
    ("식품용인증",          "food_grade_certified"),
    ("식품안전인증",        "food_safety_certified"),
    ("세트품목수",          "set_item_count"),

    # 판매·인기 지표
    ("누적판매량",          "total_sales_count"),
    ("최근30일판매",        "recent_sales_30d"),
    ("찜수",                "wishlist_count"),
    ("베스트셀러순위",      "bestseller_rank"),
    ("베스트셀러카테고리",  "bestseller_category"),
    ("재구매율",            "repurchase_rate_displayed"),

    # 리뷰
    ("평균평점",            "review_rating_avg"),
    ("리뷰수",              "review_count_total"),
    ("포토리뷰수",          "photo_review_count"),
    ("평점백분위",          "rating_percentile"),
    ("긍정키워드",          "positive_keywords"),
    ("부정키워드",          "negative_keywords"),
    ("불만카테고리",        "complaint_categories"),

    # 배송 정보
    ("배송유형",            "delivery_type"),
    ("무료배송",            "is_free_shipping"),
    ("배송비",              "shipping_cost"),
    ("무료배송최소주문",    "free_shipping_min_order"),

    # 프로모션
    ("행사여부",            "is_on_promotion"),
    ("행사유형",            "promotion_types"),
    ("타임딜",              "is_timedeal"),
    ("1+1",                 "is_one_plus_one"),
    ("쿠폰가능",            "coupon_available"),
    ("멤버십할인",          "membership_exclusive"),

    # 수집 메타
    ("수집일시",            "scraped_at"),
]


# ── CSV 생성 ──────────────────────────────────────────────────────────

def _format_cell(value) -> str:
    """CSV 셀 값 포맷팅."""
    if value is None:
        return ''
    if isinstance(value, bool):
        return 'Y' if value else 'N'
    if isinstance(value, float):
        return f"{value:.2f}"
    if isinstance(value, list):
        return ' | '.join(str(v) for v in value) if value else ''
    if isinstance(value, dict):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


def generate_csv(records: list[dict], output_path: Path) -> Path:
    """수집 데이터를 CSV로 저장. 날짜별 파일명 자동 생성."""
    today = date.today().strftime('%Y%m%d')
    csv_path = output_path / f"market_research_{today}.csv"

    headers = [col_name for col_name, _ in CSV_COLUMNS]
    field_keys = [field_key for _, field_key in CSV_COLUMNS]

    with open(csv_path, 'w', newline='', encoding='utf-8-sig') as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        for r in records:
            row = [_format_cell(r.get(key)) for key in field_keys]
            writer.writerow(row)

    return csv_path


# ── Markdown 리포트 생성 ──────────────────────────────────────────────

def _pct_bar(value: float, width: int = 20) -> str:
    """텍스트 프로그레스 바."""
    filled = int(value * width)
    return '█' * filled + '░' * (width - filled)


def generate_markdown(
    records: list[dict],
    output_path: Path,
    title: str = "주간 시장조사 리포트",
) -> Path:
    """수집 데이터를 Markdown 주간 리포트로 저장."""
    today = date.today()
    md_path = output_path / f"market_report_{today.strftime('%Y%m%d')}.md"

    lines = [
        f"# {title}",
        f"",
        f"**수집 기간**: {today.strftime('%Y년 %m월 %d일')}  ",
        f"**총 수집 상품**: {len(records):,}개  ",
        f"**생성 일시**: {datetime.now().strftime('%Y-%m-%d %H:%M')}",
        f"",
        "---",
        "",
    ]

    # 플랫폼별 요약
    platforms = sorted(set(r.get('platform', '') for r in records))
    product_types = ['위생장갑', '위생백', '지퍼백', '위생용품세트']

    for pt in product_types:
        subset = [r for r in records if r.get('product_type') == pt]
        if not subset:
            continue

        lines += [f"## {pt}", ""]

        for platform in platforms:
            group = [r for r in subset if r.get('platform') == platform]
            if not group:
                continue

            prices = [r['sale_price'] for r in group if r.get('sale_price', 0) > 0]
            unit_prices = [r['unit_price'] for r in group
                           if r.get('unit_price') and r['unit_price'] > 0]
            ratings = [r['review_rating_avg'] for r in group
                       if r.get('review_rating_avg', 0) > 0]
            disc_rates = [r['discount_rate'] for r in group
                          if r.get('discount_rate', 0) > 0]
            free_ship = sum(1 for r in group if r.get('is_free_shipping'))
            rocket = sum(1 for r in group if r.get('is_rocket_delivery'))
            sponsored = sum(1 for r in group if r.get('is_sponsored'))

            platform_label = {'coupang': '쿠팡', 'naver': '네이버쇼핑',
                               'gmarket': 'G마켓', '11st': '11번가'}.get(platform, platform)

            lines += [
                f"### {platform_label} ({len(group):,}개 상품)",
                "",
                "| 지표 | 값 |",
                "|------|----|",
                f"| 평균 판매가 | {int(sum(prices)/len(prices)):,}원 |" if prices else "| 평균 판매가 | - |",
                f"| 중앙 판매가 | {int(sorted(prices)[len(prices)//2]):,}원 |" if prices else "| 중앙 판매가 | - |",
                f"| 최저가 | {min(prices):,}원 |" if prices else "| 최저가 | - |",
                f"| 최고가 | {max(prices):,}원 |" if prices else "| 최고가 | - |",
                f"| 평균 단위가격 | {sum(unit_prices)/len(unit_prices):.1f}원/{group[0].get('unit_price_basis','개당')} |" if unit_prices else "| 평균 단위가격 | - |",
                f"| 평균 할인율 | {sum(disc_rates)/len(disc_rates)*100:.1f}% |" if disc_rates else "| 평균 할인율 | - |",
                f"| 평균 평점 | ★ {sum(ratings)/len(ratings):.2f} |" if ratings else "| 평균 평점 | - |",
                f"| 무료배송 비율 | {free_ship/len(group)*100:.0f}% ({free_ship}/{len(group)}) |",
                f"| 로켓배송 비율 | {rocket/len(group)*100:.0f}% ({rocket}/{len(group)}) |",
                f"| 광고 상품 비율 | {sponsored/len(group)*100:.0f}% ({sponsored}/{len(group)}) |",
                "",
            ]

            # 가격대 구간 분포
            tier_counts = {'저가': 0, '중가': 0, '고가': 0}
            for r in group:
                t = r.get('price_tier')
                if t in tier_counts:
                    tier_counts[t] += 1
            total_tier = sum(tier_counts.values())
            if total_tier > 0:
                lines += ["**가격대 구간 분포**", ""]
                lines += ["```"]
                for tier, cnt in tier_counts.items():
                    ratio = cnt / total_tier
                    lines.append(f"{tier:4s} {_pct_bar(ratio, 15)} {cnt:3d}개 ({ratio*100:.0f}%)")
                lines += ["```", ""]

            # 상위 브랜드
            from collections import Counter
            brand_cnt = Counter(r.get('brand_name', '') for r in group if r.get('brand_name'))
            if brand_cnt:
                lines += ["**상위 브랜드 (판매 상품 수 기준)**", ""]
                lines += ["| 순위 | 브랜드 | 상품 수 | 점유율 |",
                          "|------|--------|---------|--------|"]
                for rank, (brand, cnt) in enumerate(brand_cnt.most_common(5), 1):
                    share = cnt / len(group) * 100
                    lines.append(f"| {rank} | {brand} | {cnt} | {share:.1f}% |")
                lines += [""]

            # TOP 5 상품 (판매가 낮은 순)
            top5 = sorted(group, key=lambda r: r.get('sale_price', 0))[:5]
            if top5:
                lines += ["**최저가 TOP 5 상품**", ""]
                lines += ["| 순위 | 상품명 | 판매가 | 단위가격 | 평점 | 리뷰수 |",
                          "|------|--------|--------|----------|------|--------|"]
                for rank, r in enumerate(top5, 1):
                    name = r.get('product_name', '')[:30] + ('...' if len(r.get('product_name','')) > 30 else '')
                    price = f"{r.get('sale_price',0):,}원"
                    unit = f"{r.get('unit_price',0):.1f}원/{r.get('unit_price_basis','개당')}" if r.get('unit_price') else '-'
                    rating = f"★{r.get('review_rating_avg',0):.1f}"
                    reviews = f"{r.get('review_count_total',0):,}"
                    lines.append(f"| {rank} | {name} | {price} | {unit} | {rating} | {reviews} |")
                lines += [""]

            # 자주 언급 긍정/부정 키워드
            pos_all: Counter = Counter()
            neg_all: Counter = Counter()
            for r in group:
                for kw in r.get('positive_keywords', []):
                    pos_all[kw] += 1
                for kw in r.get('negative_keywords', []):
                    neg_all[kw] += 1

            if pos_all or neg_all:
                lines += ["**리뷰 키워드 집계**", ""]
                if pos_all:
                    top_pos = ', '.join(f"`{w}`" for w, _ in pos_all.most_common(8))
                    lines.append(f"- **긍정**: {top_pos}")
                if neg_all:
                    top_neg = ', '.join(f"`{w}`" for w, _ in neg_all.most_common(8))
                    lines.append(f"- **부정**: {top_neg}")
                lines += [""]

        lines += ["---", ""]

    lines += [
        "## 수집 방법론",
        "",
        "- 수집 플랫폼: 쿠팡, 네이버쇼핑",
        "- 수집 도구: MCP exa (URL 수집) + jina-reader (페이지 파싱)",
        "- 수집 대상: 위생장갑·위생백·지퍼백·위생용품세트",
        "- 단위 가격: 상품명/스펙에서 수량 추출 후 판매가 나누기",
        "- 가격대 구간: 동일 품목·플랫폼 내 하위33%=저가, 33~67%=중가, 상위33%=고가",
        "",
    ]

    md_path.write_text('\n'.join(lines), encoding='utf-8')
    return md_path


# ── CLI ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="시장조사 보고서 생성기")
    parser.add_argument("--input", default="data/analyzed.jsonl", help="입력 JSONL 경로")
    parser.add_argument("--output", default="data/reports", help="출력 디렉터리")
    parser.add_argument("--format", choices=["csv", "markdown", "all"], default="all")
    parser.add_argument("--title", default="주간 시장조사 리포트", help="보고서 제목")
    args = parser.parse_args()

    input_path = Path(args.input)
    output_path = Path(args.output)
    output_path.mkdir(parents=True, exist_ok=True)

    if not input_path.exists():
        print(f"[error] 파일 없음: {input_path}", file=sys.stderr)
        sys.exit(1)

    records = []
    with open(input_path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line:
                records.append(json.loads(line))

    print(f"[info] {len(records):,}개 레코드 로드", file=sys.stderr)

    if args.format in ("csv", "all"):
        csv_file = generate_csv(records, output_path)
        print(f"[csv]  {csv_file}")

    if args.format in ("markdown", "all"):
        md_file = generate_markdown(records, output_path, args.title)
        print(f"[md]   {md_file}")
