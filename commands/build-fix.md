---
description: 빌드 에러를 자동으로 분석하고 수정합니다.
allowed-tools: Read, Edit, Glob, Grep, Bash(npm:*), Bash(pnpm:*), Bash(npx:*)
---

> 참고: 이 스킬은 build-error-resolver 에이전트를 호출하지 않고 인라인 실행됩니다. 에이전트의 memory 학습이 필요하면 Agent 도구로 build-error-resolver를 직접 호출하세요.

# Build and Fix

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
