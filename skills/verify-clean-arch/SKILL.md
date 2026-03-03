---
name: verify-clean-arch
description: Clean Architecture 레이어 의존성 방향 검증. 도메인/애플리케이션/인프라 레이어 경계 위반 탐지. CS 파일 변경 후 실행.
disable-model-invocation: true
---

# verify-clean-arch

## Purpose

1. **레이어 의존성 방향** — Domain → Application → Infrastructure 단방향 의존 확인
2. **Domain 순수성** — Domain 레이어에 외부 라이브러리 참조 금지
3. **인터페이스 위치** — 인터페이스는 Domain/Application, 구현체는 Infrastructure
4. **네임스페이스 규칙** — 레이어명이 네임스페이스에 반영되어 있는지 확인
5. **직접 DB 참조 금지** — Domain/Application에서 DbContext 직접 참조 금지

## When to Run

- `.cs` 파일에서 `using` 선언이 변경된 경우
- 새 클래스/인터페이스가 추가된 경우
- 레이어 간 참조가 변경된 경우

## Related Files

| File | Purpose |
|------|---------|
| `**/Domain/**/*.cs` | 도메인 엔티티, 값 객체, 도메인 서비스 |
| `**/Application/**/*.cs` | 유스케이스, CQRS 핸들러, DTO |
| `**/Infrastructure/**/*.cs` | DB 구현, 외부 서비스 구현 |
| `**/Api/**/*.cs` / `**/Web/**/*.cs` | 컨트롤러, Blazor 페이지 |
| `**/*.csproj` | 프로젝트 참조 설정 |

## Workflow

### Step 1: Domain 레이어 외부 라이브러리 참조 확인

```bash
# Domain 프로젝트 디렉터리를 .csproj 기준으로 탐지 (Windows 경로 대소문자 무관)
# .csproj 이름에 'Domain'이 포함된 프로젝트 찾기
DOMAIN_DIRS=$(find . -name "*.csproj" | grep -i "[Dd]omain" | grep -iv "[Tt]est" | xargs -I{} dirname {})

for dir in $DOMAIN_DIRS; do
  grep -rn "^using " --include="*.cs" "$dir" | \
    grep -v "using System\|using Microsoft.Extensions\|MediatR\|FluentValidation" | \
    grep -E "EntityFrameworkCore|Supabase|HttpClient|Newtonsoft|Serilog"
done
```

**PASS**: Domain 레이어에 인프라 의존성 없음
**FAIL**: Domain에 EF Core, HttpClient 등 참조 → 인터페이스 추상화 필요

---

### Step 2: Domain/Application에서 DbContext 직접 참조 확인

```bash
# Domain 또는 Application 레이어에서 DbContext 직접 사용 탐지
grep -rn "DbContext\|AppDbContext\|DatabaseContext" --include="*.cs" . | \
  grep -iE "Domain/|Application/" | grep -v "IDbContext\|interface"
```

**PASS**: Domain/Application에서 DbContext 구체 클래스 참조 없음
**FAIL**: Domain/Application에 DbContext 직접 참조 → 인터페이스(`IAppDbContext`) 사용

---

### Step 3: .csproj 프로젝트 참조 방향 확인

```bash
# Infrastructure → Domain 역방향 참조 탐지
grep -rn "ProjectReference" --include="*.csproj" . | \
  grep -i "Infrastructure" | grep -i "Domain"
```

> Infrastructure 프로젝트가 Domain을 참조하는 것은 **올바름**.
> Domain이 Infrastructure를 참조하는 것은 **위반**.

```bash
# Domain이 Infrastructure를 참조하는 잘못된 방향 탐지
grep -rn "ProjectReference" --include="*.csproj" . | \
  grep -i "Domain" | grep -i "Infrastructure"
```

**PASS**: Domain 프로젝트에서 Infrastructure 참조 없음
**FAIL**: 역방향 의존성 → 인터페이스/DI로 역전

---

### Step 4: 네임스페이스 레이어 정합성 확인

```bash
# 파일 경로와 namespace 선언이 일치하는지 확인
grep -rn "^namespace" --include="*.cs" . | \
  grep -E "(Domain|Application|Infrastructure)" | head -20
```

**PASS**: 파일 경로의 레이어명과 namespace가 일치
**FAIL**: 경로는 Domain인데 namespace가 Infrastructure → 재배치 필요

---

### Step 5: 인터페이스-구현체 위치 확인

```bash
# Infrastructure 레이어에 인터페이스 선언 탐지 (허용되지 않음)
grep -rn "public interface " --include="*.cs" . | grep -i "Infrastructure"
```

**PASS**: Infrastructure 레이어에 인터페이스 없음
**FAIL**: Infrastructure에 인터페이스 선언 → Domain 또는 Application으로 이동

## Output Format

```
Clean Architecture 검증 결과
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Domain 순수성:           PASS / FAIL (N개 위반)
DbContext 직접 참조:     PASS / FAIL (N개 위반)
.csproj 참조 방향:       PASS / FAIL (N개 위반)
네임스페이스 정합성:      PASS / FAIL (N개 불일치)
인터페이스 위치:          PASS / FAIL (N개 위반)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Exceptions

1. **공유 커널(Shared Kernel)** — 공통 타입은 별도 프로젝트에 위치 가능
2. **MediatR, FluentValidation** — Application 레이어에서 사용 허용
3. **AutoMapper** — Application/Infrastructure 모두 허용
4. **테스트 프로젝트** — 의존성 방향 검사 제외 (`*.Tests.csproj`)
5. **Supabase.Client** — Infrastructure 레이어 한정 허용
