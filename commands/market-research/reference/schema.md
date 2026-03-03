# 시장조사 데이터 스키마 정의서

대상 품목: 위생장갑 · 위생백 · 지퍼백 · 위생용품세트
대상 플랫폼: 쿠팡, 네이버쇼핑 (우선), G마켓, 11번가 (Phase 4)
보고서 형식: CSV + Markdown

---

## 우선순위 기준
- **P0 - 필수**: 없으면 시장조사 불가
- **P1 - 중요**: 의사결정 품질 향상
- **P2 - 선택**: 여유 있을 때 수집

---

## A. 제품 기본 정보

| 필드명 | English Key | 타입 | 우선순위 | 설명 |
|--------|------------|------|---------|------|
| 상품 ID | `product_id` | str | P0 | 플랫폼 내부 상품 고유 ID |
| 상품명 | `product_name` | str | P0 | 원문 리스팅 제목 |
| 정규화 상품명 | `product_name_normalized` | str | P0 | 특수문자·이모지·과장어 제거 |
| 브랜드명 | `brand_name` | str | P0 | |
| 카테고리 경로 | `category_path` | list[str] | P1 | 예: ["생활용품","주방용품","위생장갑"] |
| 상품 URL | `product_url` | str | P0 | 정식 리스팅 URL |
| 플랫폼 | `platform` | str | P0 | coupang / naver / gmarket / 11st / auction |
| 상품 유형 | `product_type` | str | P0 | 위생장갑 / 위생백 / 지퍼백 / 위생용품세트 |
| 수집 일시 | `scraped_at` | datetime | P0 | ISO 8601 |
| 이미지 URL | `image_urls` | list[str] | P1 | 대표 이미지 + 갤러리 |
| 묶음 여부 | `is_bundle` | bool | P1 | 멀티팩 여부 |
| 키워드 태그 | `keyword_tags` | list[str] | P1 | 판매자 등록 태그 |

---

## B. 가격 정보

| 필드명 | English Key | 타입 | 우선순위 | 설명 |
|--------|------------|------|---------|------|
| 정가 | `original_price` | int | P0 | 원화(KRW), 할인 전 |
| 판매가 | `sale_price` | int | P0 | 현재 판매 가격 |
| 할인율 | `discount_rate` | float | P0 | 0.0~1.0 |
| 할인 금액 | `discount_amount` | int | P1 | KRW |
| **단위 가격** | **`unit_price`** | float | **P0** | **장당/매당/개당 단가 ← 핵심 비교 지표** |
| 단위 기준 | `unit_price_basis` | str | P0 | "장당" / "매당" / "100ml당" 등 |
| 쿠폰 적용가 | `coupon_price` | int | P1 | 최적 쿠폰 적용 후 가격 |
| 쿠폰 종류 | `coupon_type` | str | P1 | 다운로드쿠폰 / 즉시할인 / 카드할인 |
| 카드 할인 정보 | `card_discount_info` | list[dict] | P1 | [{card_name, discount_rate}] |
| 포인트 적립 | `point_reward` | int | P1 | 구매 시 적립 포인트 |
| 묶음 할인 가격 | `bundle_price` | int | P1 | N개 구매 시 가격 |
| 묶음 할인 조건 | `bundle_discount_condition` | str | P1 | 예: "2개 이상 5% 추가할인" |
| 최대 할인 적용가 | `max_discount_price` | int | P1 | 모든 할인 적용 후 최저가 |
| 가격 변동 이력 | `price_history` | list[dict] | P1 | [{date, price}] 최근 30일 |
| 최소 구매 수량 | `min_order_qty` | int | P1 | |

---

## C. 판매자 정보

| 필드명 | English Key | 타입 | 우선순위 | 설명 |
|--------|------------|------|---------|------|
| 판매자 ID | `seller_id` | str | P0 | |
| 판매자명 | `seller_name` | str | P0 | |
| 판매자 유형 | `seller_type` | str | P0 | 브랜드사 / 공식판매처 / 일반셀러 |
| 판매자 평점 | `seller_rating` | float | P0 | 0~5 |
| 판매자 리뷰 수 | `seller_review_count` | int | P1 | |
| 판매자 등급 | `seller_grade` | str | P1 | 파워셀러 / 우수셀러 / 일반 |
| 로켓배송 여부 | `is_rocket_delivery` | bool | P0 | 쿠팡 전용 |
| 공식 브랜드 스토어 | `is_brand_store` | bool | P1 | |

---

## D. 상품 스펙 (품목별 특화)

### D-1. 위생장갑 전용

| 필드명 | English Key | 타입 | 우선순위 |
|--------|------------|------|---------|
| 소재 | `glove_material` | str | P0 | PE / 비닐 / 라텍스 / 니트릴 |
| 사이즈 | `glove_size` | str | P0 | S / M / L / XL / 프리사이즈 |
| 수량(매/쌍) | `glove_qty_per_pack` | int | P0 | |
| 두께(μm) | `glove_thickness_um` | int | P1 | |
| 분말 여부 | `glove_has_powder` | bool | P1 | 무분말=False |
| 식품 접촉 인증 | `food_safety_certified` | bool | P0 | |

### D-2. 위생백 / 지퍼백 전용

| 필드명 | English Key | 타입 | 우선순위 |
|--------|------------|------|---------|
| 소재 | `bag_material` | str | P0 | PE / LDPE / 식품용 / 냉동용 |
| 사이즈 | `bag_size` | str | P0 | 소/중/대/특대 또는 mm 치수 |
| 수량(매) | `bag_qty_per_pack` | int | P0 | |
| 두께(μm) | `bag_thickness_um` | int | P1 | |
| 지퍼 유형 | `zipper_type` | str | P1 | 슬라이더 / 스냅 / 더블지퍼 / 없음 |
| 냉동 가능 | `freezer_safe` | bool | P0 | |
| 전자레인지 가능 | `microwave_safe` | bool | P0 | |
| 식품용 인증 | `food_grade_certified` | bool | P0 | |

### D-3. 위생용품세트 전용

| 필드명 | English Key | 타입 | 우선순위 |
|--------|------------|------|---------|
| 세트 구성품 | `set_components` | list[dict] | P0 | [{name, qty}] |
| 총 품목 수 | `set_item_count` | int | P0 | |
| 선물 포장 여부 | `gift_packaging` | bool | P1 | |

### D-4. 공통 스펙

| 필드명 | English Key | 타입 | 우선순위 |
|--------|------------|------|---------|
| 제조사 | `manufacturer` | str | P0 | |
| 제조국 | `country_of_origin` | str | P0 | 대한민국 / 중국 / 기타 |
| 인증 목록 | `safety_certifications` | list[str] | P1 | KC, 식품안전마크 등 |
| 인증 번호 | `certification_numbers` | list[str] | P1 | |

---

## E. 판매/인기 지표

| 필드명 | English Key | 타입 | 우선순위 | 설명 |
|--------|------------|------|---------|------|
| 누적 판매량 | `total_sales_count` | int | P0 | 전체 기간 표시 판매 수 |
| 최근 30일 판매량 | `recent_sales_30d` | int | P1 | "최근 30일 판매" 수치 |
| 찜/관심상품 수 | `wishlist_count` | int | P1 | |
| 베스트셀러 순위 | `bestseller_rank` | int | P0 | 카테고리 내 순위 |
| 베스트셀러 카테고리 | `bestseller_category` | str | P0 | 순위가 속한 카테고리 |
| 재구매율 표시 | `repurchase_rate_displayed` | str | P1 | 예: "재구매 93%" |
| 재구매 지수 | `repurchase_index` | float | P1 | 0~1 정규화 |
| 검색 노출 순위 | `search_rank` | int | P0 | 해당 키워드 검색 시 노출 순위 |
| 검색 키워드 | `search_keyword` | str | P0 | 수집에 사용한 검색어 |
| 광고 여부 | `is_sponsored` | bool | P0 | AD / 파워링크 표시 여부 |
| 신상품 여부 | `is_new_arrival` | bool | P1 | |

---

## F. 리뷰 분석

| 필드명 | English Key | 타입 | 우선순위 | 설명 |
|--------|------------|------|---------|------|
| 평균 평점 | `review_rating_avg` | float | P0 | 0~5 |
| 리뷰 총 수 | `review_count_total` | int | P0 | |
| 별점 분포 | `rating_distribution` | dict | P1 | {1:n, 2:n, 3:n, 4:n, 5:n} |
| 포토 리뷰 수 | `photo_review_count` | int | P1 | |
| 최신 리뷰일 | `latest_review_date` | str | P1 | YYYY-MM-DD |
| 긍정 키워드 Top10 | `positive_keywords` | list[str] | P1 | 텍스트에서 추출 |
| 부정 키워드 Top10 | `negative_keywords` | list[str] | P1 | 텍스트에서 추출 |
| 주요 불만 카테고리 | `complaint_categories` | list[str] | P1 | 배송/품질/포장/사이즈 |
| 리뷰 샘플 (최신 5개) | `review_samples` | list[dict] | P1 | [{rating, text, date}] |
| Q&A 수 | `qa_count` | int | P1 | |
| AI 감성 점수 | `sentiment_score` | float | P2 | 0~1, 수집 후 계산 |

---

## G. 배송 정보

| 필드명 | English Key | 타입 | 우선순위 | 설명 |
|--------|------------|------|---------|------|
| 배송 유형 | `delivery_type` | str | P0 | 로켓 / 일반 / 판매자 / 새벽 |
| 배송 예상일 | `delivery_days` | int | P0 | 일(day) 단위 |
| 당일 배송 | `same_day_delivery` | bool | P1 | |
| 새벽 배송 | `dawn_delivery` | bool | P1 | |
| 무료 배송 여부 | `is_free_shipping` | bool | P0 | |
| 배송비 | `shipping_cost` | int | P0 | KRW, 무료=0 |
| 무료배송 최소 주문액 | `free_shipping_min_order` | int | P1 | |
| 반품 가능 기간 | `return_period_days` | int | P1 | |
| 반품 배송비 | `return_shipping_cost` | int | P1 | KRW |

---

## H. 프로모션 정보

| 필드명 | English Key | 타입 | 우선순위 | 설명 |
|--------|------------|------|---------|------|
| 행사 여부 | `is_on_promotion` | bool | P0 | |
| 행사 유형 | `promotion_types` | list[str] | P0 | 타임세일/특가/묶음/1+1/2+1 |
| 행사 종료일 | `promotion_end_date` | str | P1 | ISO datetime |
| 타임딜 여부 | `is_timedeal` | bool | P1 | |
| 1+1 행사 | `is_one_plus_one` | bool | P1 | |
| 2+1 행사 | `is_two_plus_one` | bool | P1 | |
| 쿠폰 다운로드 가능 | `coupon_available` | bool | P0 | |
| 멤버십 전용 할인 | `membership_exclusive` | bool | P1 | 로켓클럽/네이버플러스 |

---

## I. 경쟁 분석 (수집 후 계산)

| 필드명 | English Key | 타입 | 우선순위 | 설명 |
|--------|------------|------|---------|------|
| 카테고리 내 순위 | `category_rank` | int | P0 | |
| 키워드 경쟁 상품 수 | `keyword_competitor_count` | int | P1 | 해당 키워드 전체 검색 결과 수 |
| 가격 백분위 | `price_percentile` | float | P1 | 0~100 |
| 평점 백분위 | `rating_percentile` | float | P1 | 0~100 |
| 가격대 구간 | `price_tier` | str | P0 | 저가 / 중가 / 고가 (계산값) |
| 유사 상품 평균가 | `similar_products_avg_price` | int | P1 | |

---

## J. 시장 트렌드 (집계 레벨 — CategoryTrendReport)

> 개별 상품이 아닌 카테고리/키워드 단위 집계 지표. 리포트 생성 시 계산.

| 필드명 | English Key | 설명 |
|--------|------------|------|
| 카테고리 평균가 | `category_avg_price` | |
| 카테고리 중앙가 | `category_median_price` | |
| 가격 범위 | `category_price_range` | {min, max, p25, p75} |
| 평균 할인율 | `category_avg_discount_rate` | |
| 상위 브랜드 점유율 | `top_brand_market_share` | {brand: share} |
| 무료 배송 비율 | `free_shipping_ratio` | |
| 로켓배송 비율 | `rocket_delivery_ratio` | 쿠팡 |
| 광고 비율 | `sponsored_ratio` | |
| 평균 평점 | `category_avg_rating` | |
| 신상품 등록 추이 | `new_product_trend` | [{week, count}] |
| 총 수집 상품 수 | `total_products_collected` | |
| 수집 기간 | `data_collection_period` | {start, end} |

---

## 플랫폼별 검색 키워드

```python
PRODUCT_KEYWORDS = {
    "위생장갑":    ["위생장갑", "비닐장갑", "일회용장갑", "PE장갑"],
    "위생백":     ["위생백", "비닐백", "식품봉투", "위생봉투"],
    "지퍼백":     ["지퍼백", "지퍼락", "지퍼팩", "냉동지퍼백"],
    "위생용품세트": ["위생용품세트", "주방위생세트", "생활위생세트"],
}
```
