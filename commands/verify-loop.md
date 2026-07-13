---
allowed-tools: Bash(npm:*), Bash(npx:*), Bash(python:*), Bash(go:*), Bash(cargo:*), Bash(make:*), Bash(git:*), Bash(rm:*), Read, Edit, Grep, Glob
description: 자동 재검증 루프 (최대 3회 재시도, 실패 시 자동 수정)
argument-hint: "[의도 설명 - handoff.md 없으면 필수] [--max-retries N] [--only build|test|lint]"
---

## Task

### 0단계: 설정 파싱
- `--max-retries N`: 최대 재시도 횟수 (기본: 3)
- `--only [type]`: 특정 검증만 실행
- 나머지: 의도 설명

### 1단계: 초기 환경 수집
1. `git status --short` - 변경사항 확인 (없으면 중단)
2. `git diff --name-only` - 변경 파일 목록
3. Read: `.claude/handoff.md` (있으면)
4. Read: `CLAUDE.md`, `spec.md`, `prompt_plan.md` (있는 것만)

### 2단계: 의도 파악
- handoff.md 있으면 → handoff.md 기반
- $ARGUMENTS에 의도 있으면 → $ARGUMENTS 기반
- 둘 다 없으면 → 안내 후 중단:
  ```
  ⚠️ 의도를 알 수 없습니다.
  /verify-loop "변경 의도 설명"으로 재시도하세요.
  ```

### 3단계: 검증 루프 시작
```
════════════════════════════════════════════════════════════════
🔄 Verification Loop 시작 (max_retries: [N])
════════════════════════════════════════════════════════════════
```

각 시도마다:

**[Attempt X/N]**

1. **코드 리뷰** (think hard):
   - `git diff` 실행
   - 의도대로 구현됐는지
   - 로직 오류, 엣지 케이스
   - 불필요한 코드 (console.log, dead code)
   - 보안 취약점

2. **자동화 검증** (프로젝트 타입별):
   - Node.js: `npm run build && npm test && npm run lint`
   - Python: `python -m pytest && python -m flake8`
   - Go: `go build ./... && go test ./...`
   - Rust: `cargo build && cargo test`

3. **결과 출력**:
   ```
   ├── Build: ✅/❌
   ├── Test: ✅/❌ (N errors)
   ├── Lint: ✅/⚠️ (N fixable)
   └── TypeCheck: ✅/❌
   ```

### 4단계: 실패 시 에러 분석
```
🔍 에러 분석 중...
├── Fixable: N개 (타입)
└── Manual: N개 (타입)
```

**Fixable 에러 (자동 수정):**
- import 누락 → 자동 추가
- 린트 포맷 → `eslint --fix` 또는 `prettier`
- 미사용 변수 → 삭제 또는 `_` prefix
- 타입 단순 오류 → 타입 추론 수정

```
🔧 자동 수정 중...
├── [수정 내용]
└── 완료
```

**Manual 에러 (안내만):**
```
⚠️ 수동 수정 필요:
  1. [파일:라인] - [에러 메시지]
  2. ...

💡 힌트: [해결 제안]
```

### 5단계: 재검증 또는 종료

**재시도 가능하면:**
- Fixable 수정 후 → 다음 Attempt로

**max_retries 도달 시:**
```
════════════════════════════════════════════════════════════════
❌ Verification Loop 실패 (N회 시도 모두 실패)
════════════════════════════════════════════════════════════════

반복 실패 에러:
  1. [에러 상세]
  2. ...

권장 조치:
  1. /handoff 실행 - 현재 상태 기록
  2. /clear 후 새 시각으로 접근
  3. /learn --from-error로 교훈 기록

🎓 자동 학습 트리거: CLAUDE.md에 패턴 기록 권장
════════════════════════════════════════════════════════════════
```

CLAUDE.md의 `## Learned Rules` 섹션에 추가 제안:
```markdown
- [날짜] [에러 패턴]: [재발 방지 규칙]
```

### 6단계: 통과 시
1. `rm .claude/handoff.md` (있으면)
2. 자동 체크포인트 저장 제안
3. 안내:
```
════════════════════════════════════════════════════════════════
✅ Verification Loop 완료 (N회 시도, 성공)
════════════════════════════════════════════════════════════════

다음 단계: /commit-push-pr --merge
```
