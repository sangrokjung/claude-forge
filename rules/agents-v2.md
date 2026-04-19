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

주요 라우팅 대상 (34 에이전트):
- 개발: planner, code-reviewer, architect, tdd-guide, build-error-resolver, verify-agent, e2e-runner, security-reviewer, database-reviewer, refactor-cleaner, doc-updater
- 비즈니스: product-strategist, quotation, crm-manager, qjc-business, qjc-operations
- 법무/재무: contract-legal, financial-accountant, patent-attorney, gov-support-strategist
- 마케팅/콘텐츠: seo-geo-aeo-strategist, copywriting, ad-optimizer-team, performance-growth-marketer, qjc-content, storyteller
- 크리에이티브: web-designer, remotion-creator
- 리서치: researcher, ai-researcher, research-pi
- 리뷰: codex-reviewer, gemini-reviewer
- 메타 사고: first-principles-thinker

상세 라우팅 테이블: `/agent-router` 스킬 참조.

## Parallel Task Execution

독립 작업은 항상 병렬 실행. 순차 실행이 필요한 경우만 예외.

## Subagents vs Agent Teams

| | Subagents | Agent Teams |
|---|---|---|
| 통신 | 메인에게만 보고 | 리더 경유 (hub-and-spoke) |
| 최적 용도 | 결과만 중요한 집중 작업 | 논의/협업이 필요한 복잡한 작업 |
| 토큰 비용 | 낮음 | 높음 |

상세: agents-teams-ref.md, agents-config-ref.md 참조.

## Agent Memory

`~/.claude/agent-memory/{agent-name}/`. 상세: agents-config-ref.md 참조.

## Agent Pipeline / Parallel Agents

- 호출 순서: ~/qjc-office/dotclaude/reference/agent-pipeline.md
- 병렬 가이드: ~/qjc-office/dotclaude/reference/parallel-agents-guide.md
