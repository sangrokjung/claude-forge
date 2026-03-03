# Database: Supabase (PostgreSQL)

## 컬럼 타입 규칙

- **`varchar(n)` 사용 금지** — 반드시 `text` 사용
  - PostgreSQL에서 `text`와 `varchar`는 내부 저장 동일, 길이 제약이 필요하면 Check Constraint로 분리
  - EF Core: `.HasColumnType("text")` 명시
- **길이 제약**: `CHECK (char_length(column) <= 255)` 방식으로 분리

```csharp
// EF Core Fluent API
entity.Property(e => e.Name)
    .HasColumnType("text")
    .HasMaxLength(200); // Check Constraint으로 자동 변환
```

## 네이밍 규칙: snake_case 필수

모든 DB 오브젝트(테이블, 컬럼, 인덱스, 함수, 트리거)는 **snake_case** 사용:

```csharp
// EF Core — NamingConventions 패키지 사용
// dotnet add package EFCore.NamingConventions
protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    => optionsBuilder.UseNpgsql(connStr).UseSnakeCaseNamingConvention();
```

```sql
-- 올바른 예
CREATE TABLE order_items (order_item_id UUID, order_id UUID, created_at TIMESTAMPTZ);

-- 금지
CREATE TABLE OrderItems (OrderItemId UUID, OrderId UUID, CreatedAt TIMESTAMPTZ);
```

## Migration 전략: EF Core 단독 사용

**Supabase Migration (`supabase db push`) 사용 금지.**

모든 스키마 변경은 EF Core Migration으로만 관리:

```bash
# 마이그레이션 추가
dotnet ef migrations add AddOrderTable --project src/Infrastructure --startup-project src/Api

# 적용
dotnet ef database update --project src/Infrastructure --startup-project src/Api

# 스크립트 생성 (프로덕션 배포용)
dotnet ef migrations script --idempotent --output migrations.sql
```

**규칙**:
- 마이그레이션 파일은 코드 리뷰 필수 (스키마 변경은 되돌리기 어려움)
- `dotnet ef migrations script --idempotent`로 SQL 파일 별도 생성하여 DBA 검토 가능하게
- 프로덕션 배포 시 자동 `Migrate()` 대신 SQL 파일 수동 적용 권장
- 모든 컬럼/테이블명은 snake_case (`UseSnakeCaseNamingConvention()` 적용 확인)
- 마이그레이션 생성 후 반드시 생성된 SQL 검토 (varchar 대신 text 여부 확인)

## RLS (Row Level Security) 의무화

**모든 테이블에 RLS 반드시 활성화.** RLS가 없는 테이블 = 보안 취약점.

```sql
-- 테이블 생성 후 즉시 RLS 활성화
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- 정책이 없으면 모든 행이 차단됨 (기본값) — 의도된 동작
-- 서비스 계정(백엔드 API)은 BYPASS RLS 권한 부여
-- 직접 Supabase SDK로 접근하는 프론트엔드는 없으므로, 백엔드 서비스 키 사용

-- 예시: 사용자 자신의 데이터만 조회 허용 (Supabase Auth 사용 시)
CREATE POLICY "Users can view own orders"
    ON orders FOR SELECT
    USING (auth.uid() = user_id);
```

**Blazor Auto는 절대 Supabase에 직접 접근하지 않음** — .NET API를 통해서만 접근.

## JSONB Audit 이력 (Trigger 자동화)

모든 중요 테이블의 변경 이력을 JSONB로 자동 저장:

```sql
-- Audit 테이블
CREATE TABLE audit_logs (
    id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    table_name  TEXT NOT NULL,
    record_id   UUID NOT NULL,
    operation   TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data    JSONB,
    new_data    JSONB,
    changed_by  UUID REFERENCES auth.users(id),
    changed_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Audit Trigger 함수
CREATE OR REPLACE FUNCTION fn_audit_trigger()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_logs (table_name, record_id, operation, old_data, new_data)
    VALUES (
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        TG_OP,
        CASE WHEN TG_OP = 'INSERT' THEN NULL ELSE row_to_json(OLD)::JSONB END,
        CASE WHEN TG_OP = 'DELETE' THEN NULL ELSE row_to_json(NEW)::JSONB END
    );
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- 테이블에 Trigger 적용
CREATE TRIGGER audit_orders
    AFTER INSERT OR UPDATE OR DELETE ON orders
    FOR EACH ROW EXECUTE FUNCTION fn_audit_trigger();
```

> ⚠️ BLOB/대용량 컬럼이 있는 테이블은 해당 컬럼 제외하여 저장. `row_to_json(NEW) - 'large_column'` 방식으로 필터.

## Audit 컬럼 표준 (모든 테이블 공통)

```sql
created_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
updated_at  TIMESTAMPTZ DEFAULT NOW() NOT NULL,
created_by  UUID REFERENCES auth.users(id),
updated_by  UUID REFERENCES auth.users(id)
```

`updated_at` 자동 갱신 Trigger:

```sql
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

## SP / Trigger 선택 가이드 (장단점 제시, 사용자 결정)

Claude는 DB 레벨 vs 앱 레벨 구현 선택이 필요할 때 아래 기준으로 트레이드오프를 설명하고 사용자가 선택하도록 한다:

**DB 레벨(SP/Trigger) 적합한 경우**:
- 복잡한 집계 (여러 테이블 조인 + 계산)
- Audit 자동화 (Trigger)
- 원자적 다중 테이블 처리 (트랜잭션 내 일관성 필수)
- 성능 임계 구간 (네트워크 왕복 최소화)

**앱 레벨(.NET) 적합한 경우**:
- 외부 API 연동이 필요한 로직
- 단위 테스트가 필요한 비즈니스 규칙
- 스케일아웃이 필요한 연산
- 복잡한 조건 분기가 있는 로직

## Connection Pooling (Npgsql)

```csharp
// Npgsql Connection String
"Host=db.xxx.supabase.co;Port=5432;Database=postgres;Username=postgres;Password=xxx;
Pooling=true;Minimum Pool Size=2;Maximum Pool Size=20;Connection Idle Lifetime=300;"
```

Supabase는 기본 최대 연결 수 제한 있음. `Maximum Pool Size * 앱 인스턴스 수 < Supabase 연결 한도` 유지.

## 인덱스 전략

- Foreign Key 컬럼에 인덱스 필수
- 검색/필터 컬럼에 적절한 인덱스 추가
- JSONB 컬럼 검색 시 GIN 인덱스 사용
- 불필요한 인덱스는 쓰기 성능 저하 유발 — 측정 후 추가
