---
name: verify-ef-migration
description: EF Core 마이그레이션 네이밍·안전성·롤백 가능성 검증. 마이그레이션 추가 후 실행.
disable-model-invocation: true
---

# verify-ef-migration

## Purpose

1. **네이밍 규칙** — 마이그레이션 이름이 PascalCase + 동사형인지 확인
2. **롤백 안전성** — `Down()` 메서드가 구현되어 있는지 확인
3. **파괴적 변경 탐지** — `DropTable`, `DropColumn` 등 데이터 손실 위험 작업 감지
4. **중복 마이그레이션** — 동일 타임스탬프 마이그레이션 감지
5. **미적용 마이그레이션** — 생성되었으나 아직 적용되지 않은 마이그레이션 확인

## When to Run

- `dotnet ef migrations add` 실행 후
- Migrations 디렉토리 파일이 변경된 경우
- PR에 마이그레이션 파일이 포함된 경우

## Related Files

| File | Purpose |
|------|---------|
| `**/Migrations/*.cs` | 마이그레이션 파일 |
| `**/Migrations/*Designer.cs` | 마이그레이션 스냅샷 |
| `**/Migrations/*ModelSnapshot.cs` | 모델 스냅샷 |

## Workflow

### Step 1: 마이그레이션 네이밍 확인

```bash
# Migrations/ 디렉토리에서 타임스탬프 제거 후 이름만 추출
find . -path "*/Migrations/*.cs" -not -name "*Designer*" -not -name "*Snapshot*" \
  | sed 's/.*[0-9]\{14\}_//' | sed 's/\.cs//'
```

**PASS**: PascalCase + 의미 있는 동사형 이름 (예: `AddUserTable`, `CreateOrderIndex`)
**FAIL**: 단순 숫자, 날짜, 또는 의미 없는 이름

---

### Step 2: Down() 메서드 구현 여부 확인

```bash
# Down 메서드가 비어있는 파일 탐지
grep -rn "protected override void Down" --include="*.cs" . -A 3 | grep -B 1 "migrationBuilder\b)" 
```

**PASS**: 모든 마이그레이션에 `Down()` 구현
**FAIL**: `Down()` 메서드 비어있음 → 롤백 불가 위험

---

### Step 3: 파괴적 변경 탐지 (CRITICAL)

```bash
# 데이터 손실 위험 작업 탐지
grep -rn "DropTable\|DropColumn\|DropDatabase\|TruncateTable\|RenameTable\|RenameColumn\|AlterColumn" \
  --include="*.cs" . | grep -v "Down()"
```

**PASS**: `Up()` 메서드에 파괴적 변경 없음
**FAIL**: `Up()` 메서드에 `DropTable`/`DropColumn` 존재 → 백업 계획 필요, CRITICAL

---

### Step 4: 중복 타임스탬프 확인

```bash
# 마이그레이션 타임스탬프 중복 여부
find . -path "*/Migrations/*.cs" -not -name "*Designer*" -not -name "*Snapshot*" \
  | sed 's/.*\/\([0-9]\{14\}\).*/\1/' | sort | uniq -d
```

**PASS**: 중복 타임스탬프 없음
**FAIL**: 중복 타임스탬프 존재 → 마이그레이션 충돌 위험

---

### Step 5: 미적용 마이그레이션 확인

```bash
# dotnet ef 도구 설치 여부 먼저 확인
if ! dotnet ef --version > /dev/null 2>&1; then
  echo "WARN: dotnet-ef 도구가 설치되지 않았습니다."
  echo "  설치 명령: dotnet tool install --global dotnet-ef"
  exit 0
fi

# Infrastructure 프로젝트 경로 자동 탐지
INFRA_PROJ=$(find . -name "*.csproj" | grep -i "Infrastructure" | grep -iv "Test" | head -1)
API_PROJ=$(find . -name "*.csproj" | grep -iE "Api|AppHost" | grep -iv "Test" | head -1)

if [[ -z "$INFRA_PROJ" ]]; then
  echo "WARN: Infrastructure 프로젝트를 찾을 수 없습니다. 경로를 직접 지정하세요."
  exit 0
fi

dotnet ef migrations list \
  --project "$INFRA_PROJ" \
  ${API_PROJ:+--startup-project "$API_PROJ"} 2>&1 | tail -10
```

**PASS**: 모든 마이그레이션 적용됨 (`(Pending)` 없음)
**WARN**: `(Pending)` 표시 마이그레이션 존재 → `dotnet ef database update` 필요
**WARN**: `dotnet-ef` 미설치 → `dotnet tool install --global dotnet-ef`로 설치 후 재실행

## Output Format

```
EF Core 마이그레이션 검증 결과
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
네이밍 규칙:       PASS / FAIL (N개 위반)
Down() 구현:       PASS / FAIL (N개 누락)
파괴적 변경:       PASS / CRITICAL (N개 감지)
중복 타임스탬프:   PASS / FAIL
미적용 마이그레이션: PASS / WARN (N개)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Exceptions

1. 초기 마이그레이션(`InitialCreate`)은 네이밍 예외 허용
2. `Down()` 비구현은 의도적인 경우 주석으로 명시 허용 (`// Intentionally empty`)
3. Supabase 관리 테이블(`auth.*`, `storage.*`) 관련 작업은 검사 제외
