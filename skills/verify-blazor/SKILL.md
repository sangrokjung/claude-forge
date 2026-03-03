---
name: verify-blazor
description: Blazor 컴포넌트 구조 및 패턴 검증. .razor 파일 변경 후, 또는 PR 전에 실행.
disable-model-invocation: true
---

# verify-blazor

## Purpose

1. **컴포넌트 구조** — `@code` 블록 위치, lifecycle 메서드 순서 검증
2. **DI 주입 패턴** — `@inject` 선언이 인터페이스 기반인지 확인
3. **인증/쿠키 처리** — 토큰을 HttpOnly 쿠키로 처리하는지 확인
4. **네이밍 규칙** — 컴포넌트 파일명이 PascalCase인지 확인
5. **렌더 모드** — `@rendermode` 선언이 의도와 일치하는지 확인

## When to Run

- `.razor` 파일이 추가/수정된 경우
- Blazor 페이지 또는 레이아웃을 변경한 경우
- 인증 흐름에 관련된 컴포넌트를 변경한 경우

## Related Files

| File | Purpose |
|------|---------|
| `**/*.razor` | Blazor 컴포넌트 파일 |
| `**/*.razor.cs` | Code-behind 파일 |
| `**/App.razor` | 앱 루트 컴포넌트 |
| `**/Routes.razor` | 라우팅 설정 |

## Workflow

### Step 1: 컴포넌트 파일명 PascalCase 확인

```bash
# .razor 파일 중 소문자로 시작하는 것 탐지
find . -name "*.razor" | grep -E "/[a-z][a-zA-Z]*\.razor$"
```

**PASS**: 결과 없음
**FAIL**: 소문자로 시작하는 `.razor` 파일 존재 → PascalCase로 변경

---

### Step 2: @inject 인터페이스 기반 여부 확인

```bash
# @inject 선언에서 구체 클래스(Impl, Service 등 접미사 없이) 사용 여부 탐지
grep -rn "@inject " --include="*.razor" . | grep -vE "@inject\s+I[A-Z]"
```

**PASS**: 모든 `@inject`가 `I`로 시작하는 인터페이스를 사용
**FAIL**: 구체 클래스 직접 주입 → 인터페이스 추출 권장

---

### Step 3: @code 블록 위치 확인

```bash
# @code 블록이 파일 중간에 있는지 확인 (마지막에 있어야 함)
grep -ln "@code" --include="*.razor" -r . | while read f; do
  total=$(wc -l < "$f")
  code_line=$(grep -n "@code" "$f" | tail -1 | cut -d: -f1)
  echo "$f: @code at line $code_line / $total"
done
```

**PASS**: `@code` 블록이 파일 하단부(80% 이후)에 위치
**FAIL**: `@code` 블록이 HTML 마크업 중간에 위치

---

### Step 4: 렌더 모드 선언 확인

```bash
# @rendermode 선언이 없는 페이지 컴포넌트 탐지
grep -rL "@rendermode" --include="*.razor" . | grep -i "page\|Pages"
```

**PASS**: 모든 페이지 컴포넌트에 `@rendermode` 선언 존재
**FAIL**: 렌더 모드 미선언 → `@rendermode InteractiveAuto` 또는 `InteractiveServer` 추가

---

### Step 5: 토큰 저장 방식 확인 (보안)

```bash
# localStorage/sessionStorage에 토큰 저장하는 패턴 탐지
grep -rn "localStorage\|sessionStorage" --include="*.razor" --include="*.razor.cs" . | grep -i "token\|jwt\|auth"
```

**PASS**: 결과 없음 (localStorage에 토큰 저장 없음)
**FAIL**: localStorage에 인증 토큰 저장 → HttpOnly 쿠키로 이전

## Output Format

```
Blazor 컴포넌트 검증 결과
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PascalCase 파일명:  PASS
@inject 인터페이스: PASS / FAIL (N개 위반)
@code 블록 위치:    PASS / FAIL (N개 위반)
@rendermode 선언:   PASS / FAIL (N개 누락)
토큰 저장 보안:     PASS / FAIL (CRITICAL)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Exceptions

1. `_Imports.razor` — 전역 using 선언 파일, 구조 규칙 미적용
2. `App.razor`, `Routes.razor` — 루트 설정 파일, rendermode 미선언 허용
3. `MainLayout.razor` — 레이아웃 파일, @code 위치 유연 허용
