---
description: Safely identify and remove dead code with test verification
---

# Refactor Clean

> **참고**: 대규모 리팩토링(3파일 이상 변경 예상)은 `/plan`을 먼저 실행하세요 (Golden Principle #9: HARD-GATE).

Safely identify and remove dead code with test verification:

1. Run dead code analysis tools:
   - knip: Find unused exports and files
   - depcheck: Find unused dependencies
   - ts-prune: Find unused TypeScript exports

2. Generate comprehensive report in .reports/dead-code-analysis.md

3. Categorize findings by severity:
   - SAFE: Test files, unused utilities
   - CAUTION: API routes, components
   - DANGER: Config files, main entry points

4. Propose safe deletions only

5. Before each deletion:
   - Run full test suite
   - Verify tests pass
   - Apply change
   - Re-run tests
   - Rollback if tests fail

6. Show summary of cleaned items

Never delete code without running tests first!

---

## 다음 단계

| 리팩토링이 끝나면 | 커맨드 |
|:----------------|:-------|
| 코드 검사 | `/code-review` |
| 빌드/테스트 검증 | `/handoff-verify` |
| 문서 동기화 | `/sync` |
