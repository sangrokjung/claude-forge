# Agent Orchestration

> 팀 운영 상세: reference/agents-teams-ref.md
> MCP/설정 상세: reference/agents-config-ref.md

## Available Agents

Located in `~/.claude/agents/`:

### 개발 에이전트

| Agent | Purpose | Model | When to Use |
|-------|---------|-------|-------------|
| planner | Implementation planning | opus | Complex features, refactoring |
| architect | System design | opus | Architectural decisions |
| tdd-guide | Test-driven development | opus | New features, bug fixes |
| code-reviewer | Code review | opus | After writing code |
| security-reviewer | Security analysis | opus | Before commits |
| build-error-resolver | Fix build errors | sonnet | When build fails |
| e2e-runner | E2E testing | sonnet | Critical user flows |
| refactor-cleaner | Dead code cleanup | sonnet | Code maintenance |
| doc-updater | Documentation | sonnet | Updating docs |
| database-reviewer | PostgreSQL/Supabase DB | opus | Schema, query optimization |
| verify-agent | Fresh-context 검증 | sonnet | /handoff-verify 서브에이전트 |

## Immediate Agent Usage

No user prompt needed:
1. Complex feature requests - Use **planner** agent
2. Code just written/modified - Use **code-reviewer** agent
3. Bug fix or new feature - Use **tdd-guide** agent
4. Architectural decision - Use **architect** agent

## Parallel Task Execution

ALWAYS use parallel Task execution for independent operations:

```markdown
# GOOD: Parallel execution
Launch 3 agents in parallel:
1. Agent 1: Security analysis of auth.ts
2. Agent 2: Performance review of cache system
3. Agent 3: Type checking of utils.ts

# BAD: Sequential when unnecessary
First agent 1, then agent 2, then agent 3
```

## Multi-Perspective Analysis

For complex problems, use split role sub-agents:
- Factual reviewer
- Senior engineer
- Security expert
- Consistency reviewer
- Redundancy checker

## Subagents vs Agent Teams

서로 통신이 필요한지에 따라 선택:

| | Subagents | Agent Teams |
|---|---|---|
| 컨텍스트 | 자체 윈도우; 결과만 호출자에 반환 | 자체 윈도우; 완전 독립 |
| 통신 | 메인 에이전트에게만 보고 | 리더 경유 기본 (hub-and-spoke). 기술 조율만 peer-to-peer 예외 |
| 조율 | 메인 에이전트가 관리 | 리더가 조율 + 공유 작업 목록 보조 |
| 최적 용도 | 결과만 중요한 집중 작업 | 논의/협업이 필요한 복잡한 작업 |
| 토큰 비용 | 낮음 (결과 요약) | 높음 (각 팀원 별도 인스턴스) |

Agent Teams 상세 운영 규칙은 reference/agents-teams-ref.md 참조.
MCP 분배 패턴 및 Subagent 선택 가이드는 reference/agents-config-ref.md 참조.

## Agent Memory

Agents with `memory: project` get persistent memory at `~/.claude/agent-memory/{agent-name}/`.

> **Note**: The `memory` field value is semantic only. All agents use the same path pattern regardless of the value set.

### Self-Evolution (Core 5 Agents)

code-reviewer, planner, architect, tdd-guide, security-reviewer automatically learn after each task:
1. Identify new patterns/edge cases
2. Record recurring issues as Learnings in memory
3. Reference previous Learnings for quality improvement
