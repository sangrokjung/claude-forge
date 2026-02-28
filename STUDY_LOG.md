# Claude Forge 학습 기록

## 개요

Claude Forge는 Claude Code를 풀 개발 환경으로 변환하는 프레임워크다. 에이전트, 커맨드, 스킬, 훅, 규칙을 `~/.claude/`에 심링크로 연결하여 동작한다.

---

## 1. 프로젝트 구조

```
claude-forge/
├── agents/          # 11개 에이전트 정의 (.md)
├── commands/        # 40개 슬래시 커맨드 (.md + SKILL 디렉토리)
├── skills/          # 15개 멀티스텝 스킬 워크플로우
├── hooks/           # 15개 이벤트 기반 셸 스크립트
├── rules/           # 8개 자동 로드 규칙 파일
├── reference/       # 참조 문서
├── knowledge/       # 지식 베이스
├── scripts/         # 유틸리티 스크립트
├── cc-chips/        # 상태 바 서브모듈
├── cc-chips-custom/ # 커스텀 상태 바 오버레이
├── setup/           # 설치 가이드 + 템플릿
├── docs/            # 스크린샷, 다이어그램
├── settings.json    # 권한, 훅, 환경변수 설정
└── mcp-servers.json # MCP 서버 정의
```

---

## 2. 에이전트 시스템

모델별로 역할이 분리되어 있다.

### Opus 에이전트 (깊은 분석)

| 에이전트 | 역할 |
|----------|------|
| planner | 구현 계획 수립 |
| architect | 시스템 설계 |
| code-reviewer | 코드 리뷰 |
| security-reviewer | 보안 분석 |
| tdd-guide | 테스트 주도 개발 |
| database-reviewer | DB 스키마/쿼리 최적화 |

### Sonnet 에이전트 (빠른 실행)

| 에이전트 | 역할 |
|----------|------|
| build-error-resolver | 빌드 에러 해결 |
| e2e-runner | E2E 테스트 실행 |
| refactor-cleaner | 데드 코드 정리 |
| doc-updater | 문서 업데이트 |
| verify-agent | Fresh-context 검증 |

---

## 3. 핵심 워크플로우

### 기능 개발
```
/plan → /tdd → /code-review → /handoff-verify → /commit-push-pr
```

### 버그 수정
```
/explore → /tdd → /verify-loop → /quick-commit
```

### 보안 감사
```
/security-review → /stride-analysis-patterns → /security-compliance
```

### 팀 협업
```
/orchestrate → Agent Teams → /commit-push-pr
```

---

## 4. MCP 서버 구성

### 설치된 글로벌 MCP

| 서버 | 패키지 | 용도 | 상태 |
|------|--------|------|------|
| context7 | @upstash/context7-mcp | 라이브러리 최신 문서 조회 | 정상 |
| memory | @modelcontextprotocol/server-memory | 세션 간 영속 메모리 (지식 그래프) | 정상 |
| exa | mcp.exa.ai (HTTP) | AI 기반 웹 검색 | 정상 |
| github | @modelcontextprotocol/server-github | GitHub PR/이슈 관리 | PAT 미설정 (gh CLI 대체) |
| fetch | mcp-server-fetch (uvx) | 웹 콘텐츠 가져오기 | 정상 |
| jina-reader | jina-mcp-tools | URL → Markdown 변환 | 캐시 재설치로 복구 완료 |
| playwright | @anthropic/mcp-playwright | 브라우저 자동화 | 정상 |
| sequential-thinking | - | 순차적 사고 지원 | 정상 |

### 트러블슈팅: jina-reader 서버 복구

**증상:** `Cannot find module 'ajv'` 에러로 서버 시작 실패

**원인:** npx 캐시(`npm-cache/_npx/`)에서 `ajv-formats`의 의존성 `ajv`가 누락

**해결:**
```bash
rm -rf ~/AppData/Local/npm-cache/_npx/84510f1fe50422de
# Claude Code 재시작 시 npx -y가 자동 재설치
```

### GitHub 연동 방식

GitHub MCP 서버는 `GITHUB_PERSONAL_ACCESS_TOKEN` 환경변수가 필요하나, 현재 미설정 상태.
대신 `gh` CLI가 keyring 기반 인증으로 정상 동작하므로, **gh CLI를 통한 GitHub 작업**으로 운영한다.

```
gh auth status
# ✓ Logged in to github.com account HarryAhn73 (keyring)
# - Token scopes: 'gist', 'read:org', 'repo'
```

---

## 5. 설정 파일 구조 (settings.json)

### 주요 설정 항목

| 항목 | 설명 |
|------|------|
| `env` | 환경변수 (Agent Teams, Tool Search, EXA API Key) |
| `permissions.allow` | 허용 도구 목록 (Bash, Read, Edit, MCP 등) |
| `permissions.deny` | 차단 패턴 (rm -rf, sudo, force push 등) |
| `hooks` | 이벤트별 자동 실행 스크립트 |
| `statusLine` | cc-chips-custom 상태 바 |

### 훅 이벤트 종류

| 이벤트 | 트리거 시점 | 주요 훅 |
|--------|------------|---------|
| PreToolUse | 도구 실행 전 | 보안 가드, 레이트 리미터 |
| PostToolUse | 도구 실행 후 | 시크릿 필터, 코드 품질 체크 |
| SessionStart | 세션 시작 시 | 컨텍스트 동기화 제안 |
| UserPromptSubmit | 사용자 입력 시 | 작업 트래커 |
| Stop | 세션 종료 시 | 세션 래핑 제안 |
| TaskCompleted | 작업 완료 시 | 완료 알림 |

---

## 6. 규칙 (Rules)

`rules/` 디렉토리의 .md 파일이 `~/.claude/rules/`에 심링크되어 모든 세션에 자동 적용된다.

| 규칙 파일 | 핵심 내용 |
|-----------|-----------|
| golden-principles.md | 불변성, 시크릿 환경변수화, TDD, 결론먼저, 작은파일, 경계검증, 비유설명 |
| coding-style.md | 불변성 패턴, 파일 200-800줄, 함수 50줄, 중첩 4단계 |
| security.md | 커밋 전 보안 체크리스트, 시크릿 관리, 보안 대응 프로토콜 |
| git-workflow-v2.md | 커밋 메시지 포맷, PR 워크플로우, TDD 접근법 |
| agents-v2.md | 에이전트 선택 가이드, 병렬 실행, Subagents vs Agent Teams |
| interaction.md | 비유 먼저 설명, 결론 먼저, 불확실하면 인정, context7 MCP 사용 |
| date-calculation.md | 날짜 계산은 반드시 시스템 도구 사용 (암산 금지) |
| testing.md | 테스트 작성 규칙 |

---

## 7. 설치 방식

### Windows (현재 환경)
```powershell
.\install.ps1
# 파일 복사 기반 (심링크 대신)
```

### macOS/Linux
```bash
./install.sh
# 심링크 기반 → git pull로 즉시 업데이트
```

---

## 8. Git Remote 구성

| Remote | 저장소 | 용도 |
|--------|--------|------|
| origin | HarryAhn73/claudestudy-project1 | 개인 학습 저장소 |
| upstream | sangrokjung/claude-forge | 원본 프로젝트 |

---

## 학습 진행 상황

### Phase 1: 구조 파악 — 완료
- [x] 디렉토리 구조와 각 폴더의 역할 이해
- [x] settings.json 설정 항목 분석
- [x] MCP 서버 구성 확인 및 트러블슈팅
- [x] GitHub 연동 방식 결정 (gh CLI)

### Phase 2: GitHub 커밋 실습 — 진행 중
- [ ] 학습 기록(STUDY_LOG.md) 커밋
- [ ] GitHub에 푸시
- [ ] 커밋 히스토리 확인

### Phase 3: 에이전트 활용 — 미진행
- [ ] planner 에이전트로 복잡한 기능 계획
- [ ] 병렬 에이전트 실행 패턴 학습

### Phase 4: 커스터마이징 — 미진행
- [ ] 새 커맨드/에이전트 추가 방법 학습
- [ ] 훅 커스터마이징 방법 학습
