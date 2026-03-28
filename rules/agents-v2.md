# Agent Orchestration

> 팀 운영 상세: ~/qjc-office/dotclaude/reference/agents-teams-ref.md
> MCP/설정 상세: ~/qjc-office/dotclaude/reference/agents-config-ref.md
> 에이전트 카탈로그: ~/qjc-office/dotclaude/reference/agent-catalog.md

## Built-in Skills

| Skill | When to Use |
|-------|-------------|
| /simplify | 기능 구현 후 코드 정리 (3 병렬 에이전트) |
| /batch | 동일 패턴 반복 변경 (5+ 파일) |
| /rc | 외출 시 원격 세션 접속 |
| /ralph-loop | 다중 턴 자율 반복 (`--max-iterations` 필수) |
| /email-action | 2-Phase 이메일 처리: 빈 입력→목록, 번호→매칭, 검색어→4-Opus 팀 (Phase 2만 에이전트 사용) |

## 에이전트 자동 라우팅 (CRITICAL)

`/agent-router` 스킬이 전문 도메인의 실질적 작업 요청을 자동 라우팅한다.
using-superpowers의 "1% 규칙"에 의해 매 턴 agent-router 체크가 강제된다.
단순 질문/정보 요청은 라우팅하지 않고 직접 답변한다.

See `/agent-router` skill for the full routing table (34+ agents across dev, business, legal, marketing, creative, research domains).

## Key Rules

- Independent tasks: always parallel. Sequential only when dependent.
- Subagents: for focused tasks (result only). Agent Teams: for collaborative tasks (discussion needed).
- Agent memory: `~/.claude/agent-memory/{agent-name}/`

> Detail: reference/agents-detail.md § Routing Table, Subagents vs Teams, Agent Memory, Pipeline Guide
