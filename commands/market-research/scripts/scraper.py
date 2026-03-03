#!/usr/bin/env python3
"""
scraper.py - 쿠팡·네이버쇼핑 시장조사 데이터 수집기

MCP 서버(exa, jina-reader, fetch)를 통해 상품 데이터를 수집하고
ProductSnapshot 데이터클래스로 구조화한다.

Claude Code에서 MCP 도구를 호출하는 방식으로 실행한다.
직접 실행 시 --dry-run 모드로 샘플 출력을 확인할 수 있다.

사용법 (Claude Code 내):
    python3 scraper.py --keyword 위생장갑 --platform coupang --limit 20
    python3 scraper.py --all --limit 50
    python3 scraper.py --dry-run

사용법 (분석):
    python3 scraper.py --stats
"""

import argparse
import json
import re
import sys
from dataclasses import dataclass, field, asdict
from datetime import datetime
from pathlib import Path
from typing import Optional


# ── 상수 ──────────────────────────────────────────────────────────────

PRODUCT_KEYWORDS: dict[str, list[str]] = {
    "위생장갑":    ["위생장갑", "비닐장갑", "일회용장갑", "PE장갑"],
    "위생백":     ["위생백", "비닐백", "식품봉투", "위생봉투"],
    "지퍼백":     ["지퍼백", "지퍼락", "지퍼팩", "냉동지퍼백"],
    "위생용품세트": ["위생용품세트", "주방위생세트", "생활위생세트"],
}

PLATFORM_SEARCH_URLS: dict[str, str] = {
    "coupang": "https://www.coupang.com/np/search?q={keyword}&channel=user",
    "naver":   "https://search.shopping.naver.com/search/all?query={keyword}",
    "gmarket": "https://search.gmarket.co.kr/search.aspx?keyword={keyword}",
    "11st":    "https://search.11st.co.kr/Search.tmall?kwd={keyword}",
    "auction": "https://browse.auction.co.kr/search?keyword={keyword}",
}

# Phase 1: 쿠팡 + 네이버쇼핑 우선
PRIORITY_PLATFORMS = ["coupang", "naver"]


# ── 데이터 모델 ────────────────────────────────────────────────────────

@dataclass
class ProductSnapshot:
    """
    단일 상품 수집 스냅샷.
    P0 필드는 모든 상품에서 반드시 수집.
    품목별 스펙 필드(glove_*, bag_*, set_*)는 해당 유형에만 적용.
    """

    # ── A. 제품 기본 정보 (P0) ──────────────────────────────────────
    product_id: str = ""
    product_name: str = ""
    product_name_normalized: str = ""
    brand_name: str = ""
    category_path: list[str] = field(default_factory=list)
    product_url: str = ""
    platform: str = ""                   # coupang / naver / gmarket / 11st / auction
    product_type: str = ""               # 위생장갑 / 위생백 / 지퍼백 / 위생용품세트
    scraped_at: str = ""                 # ISO 8601 datetime string
    image_urls: list[str] = field(default_factory=list)
    is_bundle: bool = False
    keyword_tags: list[str] = field(default_factory=list)

    # ── B. 가격 정보 (P0/P1) ───────────────────────────────────────
    original_price: int = 0              # KRW, 할인 전 정가
    sale_price: int = 0                  # 현재 판매가
    discount_rate: float = 0.0           # 0.0~1.0
    discount_amount: int = 0
    unit_price: Optional[float] = None   # 장당/매당 단가 ← 핵심 비교 지표
    unit_price_basis: Optional[str] = None  # "장당" / "매당" 등
    coupon_price: Optional[int] = None
    coupon_type: Optional[str] = None
    card_discount_info: list[dict] = field(default_factory=list)
    point_reward: int = 0
    bundle_price: Optional[int] = None
    bundle_discount_condition: Optional[str] = None
    max_discount_price: Optional[int] = None
    price_history: list[dict] = field(default_factory=list)  # [{date, price}]
    min_order_qty: int = 1

    # ── C. 판매자 정보 (P0/P1) ─────────────────────────────────────
    seller_id: str = ""
    seller_name: str = ""
    seller_type: str = ""                # 브랜드사 / 공식판매처 / 일반셀러
    seller_rating: float = 0.0
    seller_review_count: int = 0
    seller_grade: Optional[str] = None  # 파워셀러 / 우수셀러 / 일반
    is_rocket_delivery: bool = False
    is_brand_store: bool = False

    # ── D-1. 위생장갑 스펙 ──────────────────────────────────────────
    glove_material: Optional[str] = None    # PE / 비닐 / 라텍스 / 니트릴
    glove_size: Optional[str] = None        # S / M / L / 프리사이즈
    glove_qty_per_pack: Optional[int] = None
    glove_thickness_um: Optional[int] = None
    glove_has_powder: Optional[bool] = None
    food_safety_certified: Optional[bool] = None

    # ── D-2. 위생백/지퍼백 스펙 ──────────────────────────────────────
    bag_material: Optional[str] = None      # PE / LDPE / 식품용 / 냉동용
    bag_size: Optional[str] = None
    bag_qty_per_pack: Optional[int] = None
    bag_thickness_um: Optional[int] = None
    zipper_type: Optional[str] = None       # 슬라이더 / 스냅 / 더블지퍼 / 없음
    freezer_safe: Optional[bool] = None
    microwave_safe: Optional[bool] = None
    food_grade_certified: Optional[bool] = None

    # ── D-3. 위생용품세트 스펙 ───────────────────────────────────────
    set_components: list[dict] = field(default_factory=list)  # [{name, qty}]
    set_item_count: Optional[int] = None
    gift_packaging: Optional[bool] = None

    # ── D-4. 공통 스펙 ───────────────────────────────────────────────
    manufacturer: Optional[str] = None
    country_of_origin: Optional[str] = None
    safety_certifications: list[str] = field(default_factory=list)
    certification_numbers: list[str] = field(default_factory=list)

    # ── E. 판매/인기 지표 (P0/P1) ──────────────────────────────────
    total_sales_count: Optional[int] = None
    recent_sales_30d: Optional[int] = None
    wishlist_count: Optional[int] = None
    bestseller_rank: Optional[int] = None
    bestseller_category: Optional[str] = None
    repurchase_rate_displayed: Optional[str] = None
    repurchase_index: Optional[float] = None
    is_new_arrival: bool = False
    search_rank: Optional[int] = None
    search_keyword: str = ""
    is_sponsored: bool = False

    # ── F. 리뷰 분석 (P0/P1) ────────────────────────────────────────
    review_rating_avg: float = 0.0
    review_count_total: int = 0
    rating_distribution: dict = field(default_factory=dict)  # {1:n, 2:n, ...}
    photo_review_count: int = 0
    latest_review_date: Optional[str] = None
    positive_keywords: list[str] = field(default_factory=list)
    negative_keywords: list[str] = field(default_factory=list)
    complaint_categories: list[str] = field(default_factory=list)
    review_samples: list[dict] = field(default_factory=list)
    qa_count: int = 0

    # ── G. 배송 정보 (P0/P1) ────────────────────────────────────────
    delivery_type: str = ""              # 로켓 / 일반 / 판매자 / 새벽
    delivery_days: Optional[int] = None
    same_day_delivery: bool = False
    dawn_delivery: bool = False
    is_free_shipping: bool = False
    shipping_cost: int = 0
    free_shipping_min_order: Optional[int] = None
    return_period_days: Optional[int] = None
    return_shipping_cost: Optional[int] = None

    # ── H. 프로모션 정보 (P0/P1) ────────────────────────────────────
    is_on_promotion: bool = False
    promotion_types: list[str] = field(default_factory=list)
    promotion_end_date: Optional[str] = None
    is_timedeal: bool = False
    is_one_plus_one: bool = False
    is_two_plus_one: bool = False
    coupon_available: bool = False
    membership_exclusive: bool = False

    # ── I. 경쟁 분석 (수집 후 analyzer.py에서 계산) ──────────────────
    category_rank: Optional[int] = None
    keyword_competitor_count: Optional[int] = None
    price_percentile: Optional[float] = None
    rating_percentile: Optional[float] = None
    price_tier: Optional[str] = None    # 저가 / 중가 / 고가
    similar_products_avg_price: Optional[int] = None


# ── 파싱 유틸리티 ──────────────────────────────────────────────────────

def _clean_name(name: str) -> str:
    """상품명에서 특수문자, 이모지, 과장어 정규화."""
    # 이모지 제거
    name = re.sub(r'[^\w\s\-\(\)\[\]\/·,\.%]', ' ', name, flags=re.UNICODE)
    # 과장어 패턴 제거
    overstatements = ['★', '☆', '◆', '◇', '■', '□', '▶', '▷', '●', '○',
                      '특가', '초특가', '파격', '한정', '긴급', '당일마감']
    for s in overstatements:
        name = name.replace(s, '')
    return ' '.join(name.split())


def _parse_price(text: str) -> int:
    """텍스트에서 원화 가격 추출. 예: '12,900원' → 12900"""
    digits = re.sub(r'[^\d]', '', text)
    return int(digits) if digits else 0


def _parse_rating(text: str) -> float:
    """텍스트에서 평점 추출. 예: '4.8점' → 4.8"""
    m = re.search(r'(\d+\.?\d*)', text)
    return float(m.group(1)) if m else 0.0


def _parse_count(text: str) -> int:
    """텍스트에서 숫자 추출. 예: '1,234개' → 1234"""
    digits = re.sub(r'[^\d]', '', text)
    return int(digits) if digits else 0


def _detect_product_type(name: str) -> str:
    """상품명으로 품목 유형 분류."""
    name_lower = name.lower()
    if any(k in name_lower for k in ['장갑', 'glove']):
        return '위생장갑'
    if any(k in name_lower for k in ['지퍼백', '지퍼락', '지퍼팩']):
        return '지퍼백'
    if any(k in name_lower for k in ['위생백', '비닐백', '식품봉투', '위생봉투']):
        return '위생백'
    if any(k in name_lower for k in ['세트', 'set']):
        return '위생용품세트'
    return '기타'


def _infer_unit_price(
    sale_price: int,
    product_name: str,
    product_type: str,
    qty: Optional[int] = None,
) -> tuple[Optional[float], Optional[str]]:
    """
    판매가와 수량으로 단위 가격 계산.
    상품명에서 수량 추출 시도 후 계산.
    Returns: (unit_price, unit_price_basis)
    """
    if qty and qty > 0:
        basis_map = {
            '위생장갑': '장당',
            '위생백': '매당',
            '지퍼백': '매당',
            '위생용품세트': '개당',
        }
        basis = basis_map.get(product_type, '개당')
        return round(sale_price / qty, 2), basis

    # 상품명에서 수량 패턴 탐색
    patterns = [
        r'(\d+)\s*매',
        r'(\d+)\s*장',
        r'(\d+)\s*개',
        r'(\d+)\s*쌍',
        r'(\d+)\s*p\b',
        r'(\d+)\s*PCS',
    ]
    for pat in patterns:
        m = re.search(pat, product_name, re.IGNORECASE)
        if m:
            qty_found = int(m.group(1))
            if 1 < qty_found <= 10000:
                unit = sale_price / qty_found
                basis = '장당' if '장' in pat else '매당' if '매' in pat else '개당'
                return round(unit, 2), basis

    return None, None


# ── 플랫폼 파서 ────────────────────────────────────────────────────────

class CoupangParser:
    """쿠팡 상품 페이지 Markdown 파싱."""

    @staticmethod
    def parse(markdown: str, product_url: str, search_keyword: str,
              search_rank: int = 0) -> ProductSnapshot:
        p = ProductSnapshot()
        p.platform = "coupang"
        p.product_url = product_url
        p.search_keyword = search_keyword
        p.search_rank = search_rank
        p.scraped_at = datetime.now().isoformat()

        lines = markdown.split('\n')

        for i, line in enumerate(lines):
            line_s = line.strip()

            # 상품명
            if not p.product_name and re.match(r'^#{1,3}\s', line_s):
                name = re.sub(r'^#+\s+', '', line_s)
                if len(name) > 5:
                    p.product_name = name
                    p.product_name_normalized = _clean_name(name)
                    p.product_type = _detect_product_type(name)

            # 가격
            if '원' in line_s and not p.sale_price:
                prices = re.findall(r'[\d,]+원', line_s)
                if prices:
                    parsed = [_parse_price(px) for px in prices if _parse_price(px) > 1000]
                    if parsed:
                        p.sale_price = min(parsed)
                        if len(parsed) > 1:
                            p.original_price = max(parsed)

            # 할인율
            m = re.search(r'(\d+)%\s*할인', line_s)
            if m and not p.discount_rate:
                p.discount_rate = int(m.group(1)) / 100
                p.discount_amount = p.original_price - p.sale_price

            # 리뷰 수
            m = re.search(r'리뷰\s*[\(（]?\s*([\d,]+)', line_s)
            if m and not p.review_count_total:
                p.review_count_total = _parse_count(m.group(1))

            # 평점
            m = re.search(r'([\d.]+)\s*점', line_s)
            if m and not p.review_rating_avg:
                rating = float(m.group(1))
                if 0 < rating <= 5:
                    p.review_rating_avg = rating

            # 배송 유형
            if '로켓배송' in line_s:
                p.delivery_type = '로켓'
                p.is_rocket_delivery = True
            elif '새벽배송' in line_s:
                p.delivery_type = '새벽'
                p.dawn_delivery = True
            elif '오늘출발' in line_s or '당일배송' in line_s:
                p.same_day_delivery = True

            # 무료 배송
            if '무료배송' in line_s or '무료 배송' in line_s:
                p.is_free_shipping = True
                p.shipping_cost = 0

            # 광고 여부
            if '[AD]' in line_s or '광고' in line_s or 'sponsored' in line_s.lower():
                p.is_sponsored = True

            # 쿠폰
            if '쿠폰' in line_s:
                p.coupon_available = True
                m_cp = re.search(r'쿠폰\s*[\d,]+원', line_s)
                if m_cp:
                    p.coupon_type = '다운로드쿠폰'

            # 찜
            m = re.search(r'찜\s*([\d,]+)', line_s)
            if m and not p.wishlist_count:
                p.wishlist_count = _parse_count(m.group(1))

            # 판매량
            m = re.search(r'([\d,]+)\s*개\s*판매', line_s)
            if m and not p.total_sales_count:
                p.total_sales_count = _parse_count(m.group(1))

            # 재구매율
            m = re.search(r'재구매\s*(\d+)%', line_s)
            if m:
                p.repurchase_rate_displayed = f"재구매 {m.group(1)}%"
                p.repurchase_index = int(m.group(1)) / 100

            # 타임딜
            if '타임딜' in line_s or '오늘만' in line_s:
                p.is_timedeal = True
                p.is_on_promotion = True
                if '타임딜' not in p.promotion_types:
                    p.promotion_types.append('타임딜')

            # 1+1 / 2+1
            if '1+1' in line_s:
                p.is_one_plus_one = True
                p.is_on_promotion = True
            if '2+1' in line_s:
                p.is_two_plus_one = True
                p.is_on_promotion = True

        # 정가 보정 (정가 없으면 판매가 = 정가)
        if p.sale_price and not p.original_price:
            p.original_price = p.sale_price

        # 단위 가격 계산
        qty = p.glove_qty_per_pack or p.bag_qty_per_pack
        p.unit_price, p.unit_price_basis = _infer_unit_price(
            p.sale_price, p.product_name, p.product_type, qty
        )

        return p


class NaverShoppingParser:
    """네이버쇼핑 상품 페이지 Markdown 파싱."""

    @staticmethod
    def parse(markdown: str, product_url: str, search_keyword: str,
              search_rank: int = 0) -> ProductSnapshot:
        p = ProductSnapshot()
        p.platform = "naver"
        p.product_url = product_url
        p.search_keyword = search_keyword
        p.search_rank = search_rank
        p.scraped_at = datetime.now().isoformat()

        lines = markdown.split('\n')

        for line in lines:
            line_s = line.strip()

            # 상품명
            if not p.product_name and re.match(r'^#{1,3}\s', line_s):
                name = re.sub(r'^#+\s+', '', line_s)
                if len(name) > 5:
                    p.product_name = name
                    p.product_name_normalized = _clean_name(name)
                    p.product_type = _detect_product_type(name)

            # 가격
            if '원' in line_s and not p.sale_price:
                prices = re.findall(r'[\d,]+원', line_s)
                if prices:
                    parsed = [_parse_price(px) for px in prices if _parse_price(px) > 1000]
                    if parsed:
                        p.sale_price = min(parsed)
                        if len(parsed) > 1:
                            p.original_price = max(parsed)

            # 할인율
            m = re.search(r'(\d+)%', line_s)
            if m and '할인' in line_s and not p.discount_rate:
                p.discount_rate = int(m.group(1)) / 100

            # 리뷰
            m = re.search(r'리뷰\s*[\(（]?\s*([\d,]+)', line_s)
            if m and not p.review_count_total:
                p.review_count_total = _parse_count(m.group(1))

            # 평점
            m = re.search(r'([\d.]+)\s*[점/]', line_s)
            if m and not p.review_rating_avg:
                rating = float(m.group(1))
                if 0 < rating <= 5:
                    p.review_rating_avg = rating

            # 배송
            if '로켓배송' in line_s:
                p.delivery_type = '로켓'
                p.is_rocket_delivery = True
            elif '당일배송' in line_s:
                p.same_day_delivery = True

            if '무료배송' in line_s or '무료 배송' in line_s:
                p.is_free_shipping = True

            # 광고
            if '파워링크' in line_s or '[광고]' in line_s:
                p.is_sponsored = True

            # 판매자
            m = re.search(r'판매자[:\s]+([^\n\|]+)', line_s)
            if m and not p.seller_name:
                p.seller_name = m.group(1).strip()

        if p.sale_price and not p.original_price:
            p.original_price = p.sale_price

        qty = p.glove_qty_per_pack or p.bag_qty_per_pack
        p.unit_price, p.unit_price_basis = _infer_unit_price(
            p.sale_price, p.product_name, p.product_type, qty
        )

        return p


PARSERS = {
    "coupang": CoupangParser,
    "naver": NaverShoppingParser,
}


# ── 수집 조율 ──────────────────────────────────────────────────────────

def build_search_url(platform: str, keyword: str) -> str:
    """플랫폼 + 키워드 조합으로 검색 URL 생성."""
    from urllib.parse import quote
    template = PLATFORM_SEARCH_URLS.get(platform, "")
    return template.format(keyword=quote(keyword))


def collect_instructions(
    platforms: list[str],
    product_types: list[str],
    limit_per_keyword: int = 20,
) -> list[dict]:
    """
    Claude Code MCP 호출을 위한 수집 지시 목록 생성.
    실제 수집은 Claude Code가 MCP 도구로 수행한다.

    Returns:
        list of {platform, product_type, keyword, search_url, limit}
    """
    instructions = []
    for pt in product_types:
        keywords = PRODUCT_KEYWORDS.get(pt, [pt])
        for platform in platforms:
            for kw in keywords[:2]:  # 유형당 상위 2개 키워드
                instructions.append({
                    "platform": platform,
                    "product_type": pt,
                    "keyword": kw,
                    "search_url": build_search_url(platform, kw),
                    "limit": limit_per_keyword,
                })
    return instructions


def parse_from_markdown(
    markdown: str,
    platform: str,
    product_url: str,
    search_keyword: str,
    search_rank: int = 0,
) -> Optional[ProductSnapshot]:
    """Jina-reader가 반환한 Markdown으로 ProductSnapshot 생성."""
    parser_class = PARSERS.get(platform)
    if not parser_class:
        return None
    try:
        return parser_class.parse(markdown, product_url, search_keyword, search_rank)
    except Exception as e:
        print(f"[parse_error] {platform} {product_url}: {e}", file=sys.stderr)
        return None


# ── 드라이런 / CLI ─────────────────────────────────────────────────────

def _dry_run_sample() -> list[dict]:
    """수집 지시 목록 샘플 출력."""
    instructions = collect_instructions(
        platforms=PRIORITY_PLATFORMS,
        product_types=list(PRODUCT_KEYWORDS.keys()),
        limit_per_keyword=10,
    )
    return instructions


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="시장조사 수집기")
    parser.add_argument("--keyword", help="검색 키워드 (예: 위생장갑)")
    parser.add_argument("--platform", choices=list(PLATFORM_SEARCH_URLS.keys()) + ["all"],
                        default="coupang", help="수집 플랫폼")
    parser.add_argument("--all", action="store_true", help="전체 품목·플랫폼 수집")
    parser.add_argument("--limit", type=int, default=20, help="키워드당 수집 한도")
    parser.add_argument("--dry-run", action="store_true",
                        help="실제 수집 없이 수집 지시 목록만 출력")
    args = parser.parse_args()

    if args.dry_run or args.all:
        platforms = PRIORITY_PLATFORMS if not args.all else list(PLATFORM_SEARCH_URLS.keys())
        product_types = list(PRODUCT_KEYWORDS.keys())
        instructions = collect_instructions(platforms, product_types, args.limit)
        print(json.dumps(instructions, ensure_ascii=False, indent=2))
        print(f"\n총 {len(instructions)}개 수집 작업 계획됨", file=sys.stderr)
    elif args.keyword:
        platform = args.platform if args.platform != "all" else "coupang"
        url = build_search_url(platform, args.keyword)
        print(f"검색 URL: {url}")
        print("\n[안내] 실제 수집은 Claude Code에서 jina-reader / fetch MCP를 통해 수행합니다.")
        print("Claude Code에서: '위생장갑 시장조사 수집해줘' 라고 요청하세요.")
    else:
        parser.print_help()
