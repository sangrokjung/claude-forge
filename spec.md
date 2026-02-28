# Claude Forge - 기능 명세

## Feature 1: 에이전트 시스템
### 요구사항
1. Opus 에이전트 6개: 깊은 분석과 계획 (planner, architect, code-reviewer, security-reviewer, tdd-guide, database-reviewer)
2. Sonnet 에이전트 5개: 빠른 실행과 자동화 (build-error-resolver, e2e-runner, refactor-cleaner, doc-updater, verify-agent)
3. 각 에이전트는 독립적 .md 파일로 정의

### 동작 방식
- `agents/` 디렉토리의 .md 파일을 Claude Code가 자동 인식
- `~/.claude/agents/`로 심링크되어 전역 사용 가능

## Feature 2: 슬래시 커맨드
### 요구사항
1. 36개 커맨드가 카테고리별로 구성
2. 각 커맨드는 .md 파일 또는 SKILL 디렉토리로 정의

### 카테고리
- Core Workflow: plan, tdd, code-review, handoff-verify, commit-push-pr 등
- Exploration: explore, build-fix, next-task
- Security: security-review, stride-analysis-patterns, security-compliance
- Testing: e2e, test-coverage, eval
- Documentation: update-codemaps, update-docs, sync-docs

## Feature 3: 자동화 훅
### 요구사항
1. 보안 훅 6개: 시크릿 필터, 리모트 커맨드 가드, DB 가드 등
2. 유틸리티 훅 8개: 코드 품질, 컨텍스트 동기화, 세션 래핑 등
3. 이벤트 기반 트리거 (PreToolUse, PostToolUse, SessionStart, Stop 등)

## Feature 4: 심링크 설치 시스템
### 요구사항
1. macOS/Linux: 심링크 기반 (`install.sh`)
2. Windows: 파일 복사 기반 (`install.ps1`)
3. `git pull`로 즉시 업데이트 (심링크 환경)
4. 기존 설정 백업 지원
