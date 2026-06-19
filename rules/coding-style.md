---
name: coding-style
description: Coding Style
load: conditional
audience: team
sensitivity: L1
category: coding
critical: false
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.py"
  - "**/*.go"
  - "**/*.rs"
---

# Coding Style

## Immutability / File Organization

불변성, 파일/함수 크기 한계: golden-principles.md #1, #5 참조.

## Error Handling

ALWAYS handle errors comprehensively:

```typescript
try {
  const result = await riskyOperation()
  return result
} catch (error) {
  logger.error('Operation failed:', error)
  throw new Error('Detailed user-friendly message')
}
```

## Input Validation

시스템 경계에서 zod 검증: golden-principles.md #6 참조.

## Code Quality Checklist

Before marking work complete:
- [ ] Code is readable and well-named
- [ ] Functions are small (<50 lines)
- [ ] Files are focused (<800 lines)
- [ ] No deep nesting (>4 levels)
- [ ] Proper error handling
- [ ] No console.* statements (logger 사용)
- [ ] No hardcoded values
- [ ] No mutation (immutable patterns used)
- [ ] golden-principles.md 합리화 방지 테이블의 변명을 하지 않았는가?

## Security Checklist (커밋 전)

- [ ] 하드코딩된 시크릿 없음 (API 키, 비밀번호, 토큰)
- [ ] 사용자 입력 검증 (zod)
- [ ] 파라미터화 쿼리 (SQL 인젝션 방지)
- [ ] HTML 새니타이즈 (XSS 방지)
- [ ] 에러 메시지에 민감 정보 미노출
- 시크릿: `process.env`로만 접근. 미설정 시 throw
- 보안 이슈 → **code-reviewer** 에이전트로 보안 리뷰 요청

## 합리화 방지

golden-principles.md 합리화 방지 테이블 참조.
