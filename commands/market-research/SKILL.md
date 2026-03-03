---
name: market-research
description: >
  주방 위생용품(위생장갑·위생백·지퍼백·위생용품세트) 온라인 시장조사 자동화.
  쿠팡·네이버쇼핑에서 가격·판매자·리뷰·트렌드 데이터를 수집하고 CSV + Markdown 보고서를 생성한다.
  트리거 키워드: "시장조사", "market research", "경쟁분석", "가격조사",
  "위생장갑 시장", "지퍼백 트렌드", "쿠팡 최저가", "주방용품 시장",
  "상품 스크래핑", "판매 트렌드", "경쟁 상품", "단위 가격 비교".
allowed-tools: Bash(python3:*), Read, Glob
argument-hint: "[product_type] [--platform coupang|naver|all] [--limit 30] [--report]"
---

# 시장조사 명령 실행 가이드

## 빠른 시작

```
# 1. 전체 수집 지시 목록 확인
python3 commands/market-research/scripts/scraper.py --dry-run

# 2. 수집 후 분석
python3 commands/market-research/scripts/analyzer.py \
  --input commands/market-research/data/products.jsonl \
  --output commands/market-research/data/analyzed.jsonl

# 3. 보고서 생성
python3 commands/market-research/scripts/report_gen.py \
  --input commands/market-research/data/analyzed.jsonl \
  --output commands/market-research/data/reports \
  --format all
```

## 단계별 워크플로

### Step 1: 수집 준비
`scraper.py --dry-run`으로 수집 대상 URL 목록 확인.

### Step 2: MCP 수집 (Claude Code에서 실행)
각 URL에 대해:
1. `exa.searchAndContents()` - 키워드로 상품 URL 목록 수집
2. `jina-reader` - 각 상품 페이지 Markdown 변환
3. `scraper.parse_from_markdown()` - 구조화 데이터 파싱
4. `storage.save()` - JSONL 저장

### Step 3: 분석
```bash
python3 commands/market-research/scripts/analyzer.py \
  --input commands/market-research/data/products.jsonl \
  --output commands/market-research/data/analyzed.jsonl
```

### Step 4: 트렌드 집계
```bash
python3 commands/market-research/scripts/analyzer.py \
  --input commands/market-research/data/analyzed.jsonl \
  --trend --platform coupang
```

### Step 5: 보고서 생성
```bash
python3 commands/market-research/scripts/report_gen.py \
  --input commands/market-research/data/analyzed.jsonl \
  --output commands/market-research/data/reports \
  --format all
```

## 수집 대상 상품 유형

| 유형 | 검색 키워드 |
|------|------------|
| 위생장갑 | 위생장갑, 비닐장갑, 일회용장갑, PE장갑 |
| 위생백 | 위생백, 비닐백, 식품봉투, 위생봉투 |
| 지퍼백 | 지퍼백, 지퍼락, 지퍼팩, 냉동지퍼백 |
| 위생용품세트 | 위생용품세트, 주방위생세트, 생활위생세트 |

## 데이터 저장 구조
```
commands/market-research/data/
├── products.jsonl          # 원본 수집 데이터
├── analyzed.jsonl          # 분석·보정 완료 데이터
├── snapshots/YYYY-MM-DD/   # 일별 스냅샷 (가격 이력용)
└── reports/
    ├── market_research_YYYYMMDD.csv
    └── market_report_YYYYMMDD.md
```

## 스키마 참조
전체 수집 항목 정의: `commands/market-research/reference/schema.md`
