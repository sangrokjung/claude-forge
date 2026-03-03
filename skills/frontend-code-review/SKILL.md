---
name: frontend-code-review
description: "Trigger when the user requests a review of frontend files (e.g., `.tsx`, `.ts`, `.js`, `.razor`). Supports JS/TS (React) and Blazor component reviews with separate checklists."
---

# Frontend Code Review

## Intent
Use this skill whenever the user asks to review frontend code. Determine the file type first and apply the matching checklist:

- **JS/TS 모드** — `.tsx`, `.ts`, `.js` 파일 대상 (React/Next.js)
- **Blazor 모드** — `.razor`, `.razor.cs` 파일 대상 (Blazor Auto)

Support two review modes:

1. **Pending-change review** – inspect staged/working-tree files slated for commit and flag checklist violations before submission.
2. **File-targeted review** – review the specific file(s) the user names and report the relevant checklist findings.

## JS/TS 체크리스트
See [references/code-quality.md](references/code-quality.md), [references/performance.md](references/performance.md), [references/business-logic.md](references/business-logic.md) for the living checklist.

Flag each rule violation with urgency metadata so future reviewers can prioritize fixes.

## Blazor 체크리스트

`.razor` / `.razor.cs` 파일에 아래 규칙을 적용합니다:

| 항목 | 규칙 | 심각도 |
|------|------|--------|
| `@inject` 선언 | 구체 클래스 대신 인터페이스 사용 | Urgent |
| 토큰 저장 | `localStorage`/`sessionStorage` 토큰 저장 금지 → HttpOnly 쿠키 | Urgent |
| `@rendermode` | 페이지 컴포넌트에 명시적 선언 필요 | Urgent |
| `@code` 블록 위치 | 파일 최하단에 위치 | Suggestion |
| 파일명 | PascalCase 필수 | Urgent |
| `OnInitializedAsync` | 비동기 데이터 로드는 `OnInitializedAsync` 사용 | Suggestion |
| Dispose | `IDisposable` 구현 시 `@implements IDisposable` 선언 | Urgent |
| 하드코딩 문자열 | UI 문자열 리소스 파일 또는 상수로 분리 | Suggestion |

## Review Process
1. **파일 유형 판별** — 확장자 확인: `.razor`/`.razor.cs` → Blazor 모드, 그 외 → JS/TS 모드
2. **해당 체크리스트 적용** — 위 체크리스트에서 모드에 맞는 규칙만 적용
3. **JS/TS 모드**: class names, React hooks, prop memoization, styling 라인 수집
   **Blazor 모드**: `@inject`, `@code`, `@rendermode`, `@implements` 선언 수집
4. 각 규칙 위반을 탐지하고 해당 라인과 스니펫을 캡처
5. 아래 템플릿에 따라 결과 작성 — **Urgent** 먼저, 그 다음 Suggestion 순서

## Required output
When invoked, the response must exactly follow one of the two templates:

### Template A (any findings)
```
# Code review
Found <N> urgent issues need to be fixed:

## 1 <brief description of bug>
FilePath: <path> line <line>
<relevant code snippet or pointer>


### Suggested fix
<brief description of suggested fix>

---
... (repeat for each urgent issue) ...

Found <M> suggestions for improvement:

## 1 <brief description of suggestion>
FilePath: <path> line <line>
<relevant code snippet or pointer>


### Suggested fix
<brief description of suggested fix>

---

... (repeat for each suggestion) ...
```

If there are no urgent issues, omit that section. If there are no suggestions, omit that section.

If the issue number is more than 10, summarize as "10+ urgent issues" or "10+ suggestions" and just output the first 10 issues.

Don't compress the blank lines between sections; keep them as-is for readability.

If you use Template A (i.e., there are issues to fix) and at least one issue requires code changes, append a brief follow-up question after the structured output asking whether the user wants you to apply the suggested fix(es). For example: "Would you like me to use the Suggested fix section to address these issues?"

### Template B (no issues)
```
## Code review
No issues found.
```

