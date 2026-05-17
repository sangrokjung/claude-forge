# Agent Orchestration — Detail Reference

> Source: rules/agents-v2.md (core rules and built-in skills are there, details here)

## Routing Table

Major routing targets (34 agents):
- **Dev**: planner, code-reviewer, architect, tdd-guide, build-error-resolver, verify-agent, e2e-runner, security-reviewer, database-reviewer, refactor-cleaner, doc-updater
- **Business**: product-strategist, quotation, crm-manager
- **Legal/Finance**: contract-legal, financial-accountant, patent-attorney
- **Marketing/Content**: seo-geo-aeo-strategist, copywriting, ad-optimizer-team, performance-growth-marketer
- **Creative**: web-designer, remotion-creator
- **Research**: researcher, ai-researcher
- **Review**: codex-reviewer, gemini-reviewer
- **Meta**: first-principles-thinker

Full routing table with keywords: see `/agent-router` skill.

## Subagents vs Agent Teams

| | Subagents | Agent Teams |
|---|---|---|
| Communication | Report to main only | Hub-and-spoke via leader |
| Best for | Focused tasks (result only) | Complex collaborative tasks |
| Token cost | Low | High (3x+ for 3 teammates) |
| When | Default choice | Only when discussion/coordination needed |

## Agent Memory

Location: `~/.claude/agent-memory/{agent-name}/`

Core 5 agents record learnings after each task:
- planner, architect, code-reviewer, security-reviewer, tdd-guide

Memory is project-scoped and persists across sessions.

## Parallel Task Execution

Always run independent tasks in parallel. Sequential only when:
- Task B depends on Task A's output
- Tasks modify the same files
- Order matters for correctness

## Agent Pipeline Order

Typical feature development:
```
planner → tdd-guide → code-reviewer → verify-agent → doc-updater
```

For parallel agents, spawn in a single message with no dependencies between them.
