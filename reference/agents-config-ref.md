# Agent MCP 설정 참조

> 이 파일은 agents-v2.md에서 분리된 MCP 분배 및 설정 내용입니다.
> 핵심 에이전트 목록과 즉시 사용 규칙은 [agents-v2.md](agents-v2.md) 참조.
> 팀 운영 상세는 [agents-teams-ref.md](agents-teams-ref.md) 참조.

## Agent Frontmatter 필드 참조 (v2.1.63 검증 기준)

### 공식 지원 필드

| 필드 | 필수 | 타입 | 유효값 | 설명 |
|------|------|------|--------|------|
| `name` | **필수** | string | 하이픈 구분 | 에이전트 식별자 |
| `description` | **필수** | string | 트리거 조건 명시 | 자동 라우팅 기준 |
| `model` | 선택 | enum | `sonnet`, `opus`, `haiku`, `inherit` | 사용 모델 |
| `color` | 선택 | enum | `blue`, `cyan`, `green`, `yellow`, `magenta`, `red` | UI 시각 식별 |
| `tools` | 선택 | array | 도구 이름 배열 | 허용 도구 allowlist. `Agent(worker)` 형식으로 특정 subagent만 허용 가능 |
| `disallowedTools` | 선택 | array | 도구 이름 배열 | 차단 도구 denylist |
| `maxTurns` | 선택 | number | 양의 정수 | 최대 턴 수 |
| `isolation` | 선택 | enum | `worktree` | git worktree 격리 (git 저장소 필수) |
| `memory` | 선택 | string | `project`, `user` | 에이전트 전용 메모리 디렉토리 |
| `skills` | 선택 | array | 스킬 이름 배열 | 시작 시 컨텍스트에 프리로드할 스킬 |
| `mcpServers` | 선택 | array | 서버명 또는 인라인 정의 | 이 에이전트에 제공할 MCP 서버 |
| `background` | 선택 | boolean | `true`/`false` | true면 항상 백그라운드 태스크로 실행 |
| `hooks` | 선택 | object | 훅 이벤트 정의 | 에이전트 스코프 훅 (Stop 등) |
| `permissionMode` | 선택 | enum | `default`, `plan`, `acceptEdits`, `dontAsk` | **frontmatter에서 미작동** — Agent tool `mode` 파라미터로 대체 |

### 알려진 제한사항 (2026-03-02 실동작 검증)

#### tools allowlist: Write/Edit 제외 불가

`tools: ["Read", "Grep", "Glob"]`으로 설정해도 **Write와 Edit는 항상 포함**된다.
Bash, Agent 등은 allowlist로 제한 가능. 읽기 전용 에이전트가 필요하면 프롬프트의 Constraints에서 "CRITICAL: Never use Write or Edit tools" 제약을 명시해야 한다.

#### permissionMode: frontmatter에서 미작동

CLI `--permission-mode`와 Agent tool `mode` 파라미터는 `plan`, `default`, `bypassPermissions`, `acceptEdits`, `dontAsk`를 지원하지만, **frontmatter의 `permissionMode` 필드는 무시된다**. plan 모드가 필요하면 Agent tool 호출 시 `mode: "plan"` 파라미터를 직접 전달하거나, 프롬프트에서 제약해야 한다.

#### memory: project/user scope 구분 없음

`memory: project`와 `memory: user` 모두 **동일한 경로 패턴** `~/.claude/agent-memory/{agent-name}/`을 사용한다.
scope에 따른 경로 분리는 현재 미구현. 둘 다 사용자 전역 에이전트 메모리로 동작한다.

#### isolation: worktree — git 저장소 필수

`isolation: worktree`는 git 저장소 내에서만 작동한다. 비git 환경에서 실행 시 에러 발생:
`Cannot create agent worktree: not in a git repository`

#### color 시맨틱 가이드

| 색상 | 의미 | 에이전트 예시 |
|------|------|-------------|
| blue | 분석/리뷰 | planner, architect, code-reviewer |
| cyan | 테스트/검증 | tdd-guide, verify-agent, e2e-runner |
| green | 비즈니스/성공 | qjc-business, qjc-operations, qjc-content, ad-optimizer-team |
| yellow | 유지보수/데이터 | refactor-cleaner, doc-updater |
| red | 보안/경고 | security-reviewer |
| magenta | 크리에이티브/리서치 | researcher, web-designer |

## MCP 분배 패턴 (팀 워크플로우)

| 패턴 | Frontend/Writer | Backend/Designer | Tester/Distributor |
|------|----------------|------------------|--------------------|
| 풀스택 | playwright, stitch | memory, desktop-commander | playwright, analytics |
| 콘텐츠 | exa, yt-dlp (자막1순위), youtube-transcript (폴백) | stitch, remotion | gmail, google-calendar |
| 마케팅 | analytics, ads MCPs | remotion, stitch | n8n, gmail |

## MCP-Aware Subagent 선택 가이드

| 필요 MCP | 권장 type | 이유 |
|----------|-----------|------|
| gmail, calendar, n8n, playwright, memory, analytics, ads, data-go-* | general-purpose | Write/Bash 접근 필요 |
| exa, context7 | Explore | 읽기 전용 리서치 |

## Excalidraw MCP

아키텍처 다이어그램, 워크플로우 시각화에 사용.

| 설정 | 값 |
|------|-----|
| 패키지 | `@pinka/mcp-server-excalidraw` |
| 상태 | disabled (패키지 확인 후 활성화) |
| 접근 에이전트 | planner, architect |
| 용도 | 아키텍처 다이어그램, 시스템 흐름도, 워크플로우 시각화 |

### 사용 시나리오

- planner: 구현 계획에 시각적 다이어그램 포함
- architect: 시스템 아키텍처 시각화
- 일반 세션: 복잡한 흐름을 다이어그램으로 설명
