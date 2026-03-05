# Agent Orchestration

> Team operations: reference/agents-teams-ref.md
> MCP/config: reference/agents-config-ref.md

## Available Agents

Located in `~/.claude/agents/`:

### Development Agents

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
| verify-agent | Fresh-context verification | sonnet | /handoff-verify subagent |

## Built-in Skills

Claude Code includes built-in slash commands that should be used when appropriate:

| Skill | Purpose | When to Use |
|-------|---------|-------------|
| `/simplify` | Reduce code complexity | After implementation, during refactoring |
| `/batch` | Process multiple files/tasks | Repetitive operations across files |
| `/rc` | Run configuration commands | Project setup, config changes |

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

Choose based on whether communication between agents is needed:

| | Subagents | Agent Teams |
|---|---|---|
| Context | Own window; returns results to caller only | Own window; fully independent |
| Communication | Reports to main agent only | Hub-and-spoke via leader. Peer-to-peer only for technical coordination |
| Coordination | Main agent manages | Leader coordinates + shared task list |
| Best for | Focused tasks where only results matter | Complex tasks requiring discussion/collaboration |
| Token cost | Low (result summaries) | High (separate instance per member) |

See reference/agents-teams-ref.md for detailed team operation rules.
See reference/agents-config-ref.md for MCP distribution and subagent selection guide.

## Agent Memory

Agents with `memory: project` get persistent memory at `~/.claude/agent-memory/{agent-name}/`.

> **Note**: The `memory` field value is semantic only. All agents use the same path pattern regardless of the value set.

### Self-Evolution (Core 5 Agents)

code-reviewer, planner, architect, tdd-guide, security-reviewer automatically learn after each task:
1. Identify new patterns/edge cases
2. Record recurring issues as Learnings in memory
3. Reference previous Learnings for quality improvement
