# 플랫폼별 수집 가이드

## 수집 우선순위

| 순위 | 플랫폼 | 특징 | Phase |
|------|--------|------|-------|
| 1 | 쿠팡 (coupang) | 로켓배송·최대 트래픽 | 1 |
| 2 | 네이버쇼핑 (naver) | 가격비교 허브·다양한 셀러 | 1 |
| 3 | G마켓 (gmarket) | 이베이코리아 계열·옥션 연동 | 4 |
| 4 | 11번가 (11st) | SK텔레콤 계열 | 4 |

---

## 쿠팡 (coupang.com)

### 검색 URL
```
https://www.coupang.com/np/search?q={keyword}&channel=user
```

### 상품 URL 패턴
```
https://www.coupang.com/vp/products/{product_id}
```

### 주요 특이사항
- **로켓배송**: 쿠팡 자체 물류. `is_rocket_delivery=True` 표시
- **로켓클럽**: 멤버십 전용 추가 할인 가능 `membership_exclusive=True`
- **새벽배송**: 전날 자정 전 주문 시 새벽 도착
- **파트너스/광고**: `[AD]` 또는 `광고` 표시로 식별 → `is_sponsored=True`
- **로켓그로스**: 판매자 물건을 쿠팡 창고 보관 (로켓배송처럼 보임)

### jina-reader 파싱 팁
- 상품명: 첫 번째 `<h1>` 태그 또는 최상위 `##` Heading
- 가격: `원` 앞 숫자 패턴 `[\d,]+원`
- 리뷰 수: "리뷰 (N,NNN)" 패턴
- 재구매율: "재구매 N%" 패턴 탐색

### 수집 제한사항
- JavaScript 렌더링 필요 → jina-reader 사용 필수
- 분당 요청 제한 있음 → 요청 간 2~4초 대기 권장
- 로그인 필요 시 일부 가격 정보 미노출

---

## 네이버쇼핑 (search.shopping.naver.com)

### 검색 URL
```
https://search.shopping.naver.com/search/all?query={keyword}
```

### 상품 URL 패턴
```
https://search.shopping.naver.com/catalog/{catalog_id}
https://smartstore.naver.com/{store_name}/products/{product_id}
```

### 주요 특이사항
- **가격비교**: 동일 상품에 여러 셀러가 등록 → 최저가 식별 중요
- **파워링크**: 광고 상품 → `is_sponsored=True`
- **네이버플러스**: 멤버십 추가 적립 → `membership_exclusive=True`
- **스마트스토어**: 개인 판매자~브랜드까지 다양

### jina-reader 파싱 팁
- 가격: "최저 N,NNN원" 패턴 탐색
- 판매처: "판매처: N개" 패턴 (복수 셀러)
- 리뷰: "리뷰 N,NNN건" 패턴
- 배송: "무료배송" / "N원" 패턴

### 수집 제한사항
- JavaScript 렌더링 의존도 높음
- 가격비교 페이지는 개별 셀러가 아닌 대표가 표시됨
- 실제 구매 셀러 파악을 위해 셀러 목록 페이지 추가 방문 필요

---

## G마켓 (gmarket.co.kr) — Phase 4

### 검색 URL
```
https://search.gmarket.co.kr/search.aspx?keyword={keyword}
```

### 주요 특이사항
- 슈퍼딜: 타임딜 상품 → `is_timedeal=True`
- G마켓 빅세일: 대형 기획전 참여 여부 확인

---

## 11번가 (11st.co.kr) — Phase 4

### 검색 URL
```
https://search.11st.co.kr/Search.tmall?kwd={keyword}
```

### 주요 특이사항
- SK페이 혜택 → `card_discount_info` 활용
- 쇼킹딜: 타임딜 상품 → `is_timedeal=True`

---

## MCP 서버 활용 전략

### exa 서버
```
용도: 키워드 기반 상품 URL 수집
호출: exa.searchAndContents(
  query="쿠팡 위생장갑",
  numResults=20,
  includeDomains=["coupang.com"]
)
```

### jina-reader 서버
```
용도: 상품 페이지 Markdown 변환
호출: jina.reader(url=product_url)
결과: Markdown 텍스트 → 파서로 구조화
```

### fetch 서버
```
용도: jina-reader 실패 시 폴백, 네이버쇼핑 보조
호출: fetch.fetch(url=search_url, max_length=5000)
```

---

## 요청 간격 권장사항

| 플랫폼 | 요청 간격 | 재시도 |
|--------|----------|--------|
| 쿠팡 | 2~4초 | 3회 (지수 백오프) |
| 네이버쇼핑 | 1~3초 | 3회 |
| G마켓/11번가 | 2~5초 | 2회 |
