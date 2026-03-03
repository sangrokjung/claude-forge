# 온라인 플랫폼 자동 시장조사 프로그램

주방 위생용품(위생장갑·위생백·지퍼백·위생용품세트)을 대상으로 쿠팡·네이버쇼핑의 가격·경쟁·트렌드 데이터를 자동 수집하고 CSV + Markdown 보고서를 생성하는 시장조사 프로그램.

---

## 빠른 시작

```bash
cd commands/market-research

# 1. 수집 지시 목록 확인 (드라이런)
python3 scripts/scraper.py --dry-run

# 2. 분석 (수집 데이터 있을 때)
python3 scripts/analyzer.py \
  --input data/products.jsonl \
  --output data/analyzed.jsonl

# 3. 보고서 생성
python3 scripts/report_gen.py \
  --input data/analyzed.jsonl \
  --output data/reports \
  --format all

# 4. 스토리지 통계
python3 scripts/storage.py --data-dir data --stats
```

---

## 수집 항목 (10개 카테고리, 총 ~100개 필드)

| 카테고리 | 필드 수 | 주요 필드 |
|----------|--------|---------|
| A. 제품 기본 정보 | 12 | product_name, platform, product_type |
| B. 가격 정보 | 14 | **unit_price**, sale_price, discount_rate |
| C. 판매자 정보 | 8 | seller_name, seller_type, is_rocket_delivery |
| D. 상품 스펙 | 25+ | 품목별 소재·수량·인증 |
| E. 판매/인기 지표 | 11 | bestseller_rank, total_sales_count, is_sponsored |
| F. 리뷰 분석 | 11 | review_rating_avg, positive_keywords |
| G. 배송 정보 | 9 | delivery_type, is_free_shipping |
| H. 프로모션 정보 | 8 | is_on_promotion, coupon_available |
| I. 경쟁 분석 | 6 | price_tier, price_percentile |
| J. 시장 트렌드 | 12 | category_avg_price, top_brand_market_share |

> **핵심 비교 지표**: `unit_price` (장당/매당 단가) — 상품마다 수량이 달라 판매가 직접 비교 불가. 단위 가격만이 공정한 비교 기준.

전체 필드 정의: [`reference/schema.md`](reference/schema.md)

---

## 수집 대상

### 플랫폼 (우선순위)
1. **쿠팡** (coupang.com) — 로켓배송, 최대 트래픽
2. **네이버쇼핑** (search.shopping.naver.com) — 가격비교 허브

### 품목 & 검색 키워드

| 품목 | 키워드 |
|------|--------|
| 위생장갑 | 위생장갑, 비닐장갑, 일회용장갑, PE장갑 |
| 위생백 | 위생백, 비닐백, 식품봉투, 위생봉투 |
| 지퍼백 | 지퍼백, 지퍼락, 지퍼팩, 냉동지퍼백 |
| 위생용품세트 | 위생용품세트, 주방위생세트, 생활위생세트 |

---

## 파일 구조

```
commands/market-research/
├── SKILL.md                     # Claude Code 명령 진입점
├── README.md                    # 이 파일
│
├── scripts/
│   ├── scraper.py               # 플랫폼 파서 + 수집 지시 생성
│   ├── analyzer.py              # 단가 계산·백분위·리뷰 키워드 추출
│   ├── storage.py               # JSONL 저장·스냅샷·가격 이력
│   └── report_gen.py            # CSV + Markdown 보고서 생성
│
├── reference/
│   ├── schema.md                # 전체 필드 정의서 (100개 필드)
│   ├── platforms.md             # 플랫폼별 URL 패턴·파싱 팁
│   └── product-types.md         # 품목별 스펙 기준·단위 가격 계산법
│
├── examples/
│   └── sample_products.jsonl    # 5개 샘플 상품 데이터
│
└── data/                        # .gitignore 대상 (런타임 데이터)
    ├── products.jsonl
    ├── analyzed.jsonl
    ├── snapshots/YYYY-MM-DD/
    └── reports/
```

---

## 워크플로 아키텍처

```
Claude Code (시장조사 명령)
    │
    ├── exa MCP ──────────────── 키워드로 상품 URL 수집
    ├── jina-reader MCP ───────── URL → Markdown 변환
    │                             │
    │                             ▼
    ├── scraper.py ────────────── Markdown 파싱 → ProductSnapshot
    ├── storage.py ────────────── JSONL 저장 + 스냅샷
    ├── analyzer.py ───────────── 단가·백분위·리뷰 키워드 계산
    └── report_gen.py ──────────── CSV + Markdown 보고서 생성
```

---

## 보고서 예시 (Markdown)

```
## 위생장갑 — 쿠팡 (47개 상품)

| 지표 | 값 |
|------|----|
| 평균 판매가 | 8,230원 |
| 평균 단위가격 | 41.2원/장당 |
| 평균 할인율 | 21.3% |
| 평균 평점 | ★ 4.52 |
| 무료배송 비율 | 89% |
| 로켓배송 비율 | 67% |
| 광고 상품 비율 | 18% |

가격대 분포:
저가 ██████░░░░░░░░░  15개 (32%)
중가 ████████████░░░  22개 (47%)
고가 ████░░░░░░░░░░░  10개 (21%)

긍정 키워드: `만족` `편리` `무분말` `식품용` `두껍`
부정 키워드: `얇아요` `찢어짐` `냄새`
```

---

## 구현 단계

| 단계 | 상태 | 내용 |
|------|------|------|
| Phase 1 | ✅ | 스키마·스토리지·샘플 데이터 |
| Phase 2 | ✅ | scraper.py 쿠팡·네이버 어댑터 |
| Phase 3 | ✅ | analyzer.py 단가·백분위·리뷰 키워드 |
| Phase 4 | ✅ | report_gen.py CSV + Markdown |
| Phase 5 | 예정 | 가격 이력 추적·G마켓·11번가·스케줄러 |

---

## 참조
- 전체 스키마: [`reference/schema.md`](reference/schema.md)
- 플랫폼 가이드: [`reference/platforms.md`](reference/platforms.md)
- 품목 분류: [`reference/product-types.md`](reference/product-types.md)
- 샘플 데이터: [`examples/sample_products.jsonl`](examples/sample_products.jsonl)
