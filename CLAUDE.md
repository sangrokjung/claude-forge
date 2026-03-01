# Claude Forge

> Claude Code를 완전한 개발 환경으로 만드는 오픈소스 프레임워크.
> "oh-my-zsh for Claude Code" — 에이전트, 커맨드, 스킬, 훅, 룰을 한 번에 설치.

## 기술 스택

- **언어**: Bash (install/hooks), Markdown (agents/commands/skills/rules)
- **플랫폼**: macOS, Linux, WSL
- **의존성**: Claude Code >= 1.0, Node.js, Git
- **MCP 서버**: context7, memory, exa, github, fetch, jina-reader
- **설치 방식**: symlink 기반 (`install.sh` → `~/.claude/`)

## 빌드 & 테스트

- 빌드: 없음 (Markdown + Bash 기반, 컴파일 불필요)
- 테스트: `./install.sh`로 symlink 무결성 확인
- 린트: shellcheck (hooks/*.sh), markdownlint (*.md)

## 디렉토리 구조

```
claude-forge/
  agents/          11개 전문 에이전트 (planner, tdd-guide, code-reviewer 등)
  commands/        40개 슬래시 커맨드 (/plan, /tdd, /auto 등)
  skills/          32개 스킬 워크플로우 (brainstorming, verification-engine 등)
  hooks/           16개 자동화 훅 (보안 필터, 품질 리마인더, 비용 추적 등)
  rules/           8개 코딩 규칙 (golden-principles, security, coding-style 등)
  reference/       참조 문서 (에이전트 팀, MCP 설정 등)
  docs/            사용자 문서 (FIRST-STEPS, WORKFLOW-RECIPES)
  setup/           설치 보조 파일
  scripts/         유틸리티 스크립트
  cc-chips/        하단바 상태 표시 (git submodule)
  cc-chips-custom/ 커스텀 하단바 확장
  settings.json    전역 설정 (권한, 훅, 환경변수)
  mcp-servers.json MCP 서버 설정
  install.sh       설치 스크립트 (macOS/Linux/WSL)
  install.ps1      설치 스크립트 (Windows PowerShell)
```

## 핵심 워크플로우

```
기능 개발: /plan → /tdd → /code-review → /handoff-verify → /commit-push-pr
버그 수정: /explore → /tdd → /verify-loop → /quick-commit
보안 감사: /security-review → /stride-analysis-patterns → /security-compliance
전체 자동: /auto [작업 설명]
```

## 코딩 컨벤션

### Bash (hooks, scripts)
- `set -e` 필수
- shellcheck 통과 필수
- 타임아웃 설정 (5000ms 기본)
- 비파괴적 실패 처리 (훅 실패가 전체 세션을 중단시키면 안 됨)

### Markdown (agents, commands, skills, rules)
- 단계별 구조 (## 1단계, ## 2단계)
- 명확한 트리거 조건 명시
- 입출력 형식 예시 포함
- 800줄 이하 유지

### 새 컴포넌트 추가 시
- **에이전트**: `agents/[name].md` 생성, model/tools/allowedTools 명시
- **커맨드**: `commands/[name].md` 생성, 파라미터 파싱 + 단계별 실행 구조
- **스킬**: `skills/[name]/` 디렉토리 생성, `skill.md` + 옵셔널 `hooks/`
- **훅**: `hooks/[name].sh` 생성, `settings.json`에 매처 등록
- **룰**: `rules/[name].md` 생성

## 보안 정책

- `settings.json`의 deny 목록에 위험한 Bash 패턴 차단
- `output-secret-filter.sh`로 출력에서 시크릿 자동 필터링
- `remote-command-guard.sh`로 원격 명령 실행 방지
- `security-auto-trigger.sh`로 Edit/Write 시 보안 검사 자동 실행
- force push to main/master 차단

## 기업용 확장 고려사항

- 팀별 settings.json 오버라이드 지원
- RBAC(역할 기반 접근 제어) 패턴 준비
- 프라이빗 MCP 서버 설정 분리 (settings.local.json)
- 감사 로그 (work-tracker-*.sh)
- 멀티 프로젝트 환경에서의 격리 (worktree 기반)
