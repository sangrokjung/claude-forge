# 품목별 분류 기준 및 스펙 정의

## 수집 대상 4개 품목

---

## 1. 위생장갑 (Sanitary Gloves)

### 분류 키워드
- 위생장갑, 비닐장갑, 일회용장갑, PE장갑, 라텍스장갑, 니트릴장갑

### 핵심 스펙 필드
| 필드 | 가능한 값 | 중요도 |
|------|----------|--------|
| `glove_material` | PE / 비닐 / 라텍스 / 니트릴 | 최고 |
| `glove_size` | S / M / L / XL / 프리사이즈 | 최고 |
| `glove_qty_per_pack` | 50~1000 (매/쌍) | 최고 |
| `glove_has_powder` | True(분말) / False(무분말) | 높음 |
| `glove_thickness_um` | 10~50 μm | 중간 |
| `food_safety_certified` | True / False | 최고 |

### 단위 가격 계산
- 기준: `장당` (매당)
- 공식: `unit_price = sale_price / glove_qty_per_pack`
- 예: 200매 6,900원 → 34.5원/장

### 소재별 용도 가이드
| 소재 | 주요 용도 | 가격대 |
|------|----------|--------|
| PE/비닐 | 일반 주방, 청소 | 저가 |
| 라텍스 | 의료·식품가공 | 중가 |
| 니트릴 | 화학물 취급, 의료 | 고가 |

### 인증 체크리스트
- KC 안전인증 (가전·생활용품 필수)
- 식품위생법 적합 인증 (식품 접촉용)

---

## 2. 위생백 (Sanitary Bags)

### 분류 키워드
- 위생백, 비닐백, 식품봉투, 위생봉투, 비닐봉투(식품용)

### 핵심 스펙 필드
| 필드 | 가능한 값 | 중요도 |
|------|----------|--------|
| `bag_material` | PE / LDPE / HDPE / 냉동용 | 최고 |
| `bag_size` | 소/중/대/특대 또는 mm×mm | 최고 |
| `bag_qty_per_pack` | 50~500 (매) | 최고 |
| `bag_thickness_um` | 20~80 μm | 중간 |
| `freezer_safe` | True / False | 높음 |
| `food_grade_certified` | True / False | 최고 |

### 단위 가격 계산
- 기준: `매당`
- 공식: `unit_price = sale_price / bag_qty_per_pack`

### 사이즈 기준표
| 규격 | 대략적 치수 |
|------|------------|
| 소형 | ~15×20cm |
| 중형 | 20×25cm |
| 대형 | 25×35cm |
| 특대 | 35×50cm 이상 |

---

## 3. 지퍼백 (Zipper Bags)

### 분류 키워드
- 지퍼백, 지퍼락, 지퍼팩, 냉동지퍼백, 슬라이더지퍼백

### 핵심 스펙 필드
| 필드 | 가능한 값 | 중요도 |
|------|----------|--------|
| `bag_material` | PE / LDPE / PA / 냉동용 | 최고 |
| `bag_size` | 소/중/대/특대 또는 mm×mm | 최고 |
| `bag_qty_per_pack` | 20~200 (매) | 최고 |
| `zipper_type` | 슬라이더 / 스냅 / 더블지퍼 / 단순잠금 | 높음 |
| `freezer_safe` | True / False | 최고 |
| `microwave_safe` | True / False | 높음 |
| `food_grade_certified` | True / False | 최고 |

### 지퍼 유형별 특징
| 유형 | 특징 | 가격대 |
|------|------|--------|
| 스냅(일반) | 양손으로 꾹 눌러 잠금 | 저가 |
| 슬라이더 | 슬라이더 손잡이로 개폐 | 중가 |
| 더블지퍼 | 이중 잠금, 밀봉성 높음 | 고가 |

### 단위 가격 계산
- 기준: `매당`
- 공식: `unit_price = sale_price / bag_qty_per_pack`

---

## 4. 위생용품세트 (Hygiene Product Sets)

### 분류 키워드
- 위생용품세트, 주방위생세트, 생활위생세트, 위생용품묶음, 주방세트선물

### 핵심 스펙 필드
| 필드 | 가능한 값 | 중요도 |
|------|----------|--------|
| `set_components` | [{name, qty}, ...] | 최고 |
| `set_item_count` | 2~10 | 최고 |
| `gift_packaging` | True / False | 중간 |
| `is_bundle` | True | 최고 (항상 True) |

### 세트 구성 예시
```json
[
  {"name": "위생장갑", "qty": 100},
  {"name": "지퍼백 중형", "qty": 50},
  {"name": "위생백 소형", "qty": 50},
  {"name": "비닐봉투", "qty": 50}
]
```

### 단위 가격 계산
- 세트는 총 아이템 수 기준
- 공식: `unit_price = sale_price / sum(comp.qty for comp in set_components)`
- 예: 총 250개 구성 18,900원 → 75.6원/개
- 대안: 세트당 가격 그대로 비교 (직접 비교 어려움 주의)

---

## 상품 유형 자동 분류 로직

```python
def detect_product_type(product_name: str) -> str:
    name = product_name.lower()
    if any(k in name for k in ['장갑', 'glove']):
        return '위생장갑'
    if any(k in name for k in ['지퍼백', '지퍼락', '지퍼팩']):
        return '지퍼백'
    if any(k in name for k in ['위생백', '비닐백', '식품봉투', '위생봉투']):
        return '위생백'
    if any(k in name for k in ['세트', 'set']):
        return '위생용품세트'
    return '기타'
```

---

## 가격 비교 시 주의사항

1. **수량 기준 통일**: 장갑은 장당, 백류는 매당으로 단위 가격 환산 필수
2. **묶음 상품**: is_bundle=True인 경우 개별 상품 단가와 직접 비교 불가
3. **세트 가격**: 세트 구성이 다르면 직접 비교 불가 → 구성품별 분해 후 비교
4. **쿠폰/카드 할인**: max_discount_price 기준으로 실질 비교
5. **배송비**: 배송비 포함 최종 가격 비교 (total_cost = sale_price + shipping_cost)
