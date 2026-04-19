---
description: Incrementally fix TypeScript and build errors one at a time
---

# Build and Fix

> **참고**: 빌드 에러가 아키텍처 문제에서 기인하는 경우, `/plan`으로 구조적 해결 방안을 먼저 수립하세요.

Incrementally fix TypeScript and build errors:

1. Run build: npm run build or pnpm build

2. Parse error output:
   - Group by file
   - Sort by severity

3. For each error:
   - Show error context (5 lines before/after)
   - Explain the issue
   - Propose fix
   - Apply fix
   - Re-run build
   - Verify error resolved

4. Stop if:
   - Fix introduces new errors
   - Same error persists after 3 attempts
   - User requests pause

5. Show summary:
   - Errors fixed
   - Errors remaining
   - New errors introduced

Fix one error at a time for safety!

---

## 다음 단계

| 빌드 수정이 끝나면 | 커맨드 |
|:-----------------|:-------|
| 전체 검증 | `/handoff-verify` |
| 빠른 커밋 | `/quick-commit` |
| 문서 동기화 | `/sync` |
