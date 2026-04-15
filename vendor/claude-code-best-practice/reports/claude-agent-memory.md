# Claude Code: Agent Memory Frontmatter

Persistent memory for subagents — enabling agents to learn, remember, and build knowledge across sessions.

<table width="100%">
<tr>
<td><a href="../">← Back to Claude Code Best Practice</a></td>
<td align="right"><img src="../!/claude-jumping.svg" alt="Claude" width="60" /></td>
</tr>
</table>

---

## Overview

Introduced in **Claude Code v2.1.33** (February 2026), the `memory` frontmatter field gives each subagent its own persistent markdown-based knowledge store. Before this, every agent invocation started from scratch.

```yaml
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Write, Edit, Bash
model: sonnet
memory: user
---

You are a code reviewer. As you review code, update your agent memory with
patterns, conventions, and recurring issues you discover.
```

---

## Memory Scopes

| Scope | Storage Location | Version Controlled | Shared | Best For |
|-------|-----------------|-------------------|--------|----------|
| `user` | `~/.claude/agent-memory/<agent-name>/` | No | No | Cross-project knowledge (recommended default) |
| `project` | `.claude/agent-memory/<agent-name>/` | Yes | Yes | Project-specific knowledge the team should share |
| `local` | `.claude/agent-memory-local/<agent-name>/` | No (git-ignored) | No | Project-specific knowledge that's personal |

These scopes mirror the settings hierarchy (`~/.claude/settings.json` → `.claude/settings.json` → `.claude/settings.local.json`).

---

## How It Works

1. **On startup**: First 200 lines of `MEMORY.md` are injected into the agent's system prompt
2. **Tool access**: `Read`, `Write`, `Edit` are auto-enabled so the agent can manage its memory
3. **During execution**: The agent reads/writes to its memory directory freely
4. **Curation**: If `MEMORY.md` exceeds 200 lines, the agent moves details into topic-specific files

```
~/.claude/agent-memory/code-reviewer/     # user scope example
├── MEMORY.md                              # Primary file (first 200 lines loaded)
├── react-patterns.md                      # Topic-specific file
└── security-checklist.md                  # Topic-specific file
```

---

## Agent Memory vs Other Memory Systems

| System | Who Writes | Who Reads | Scope |
|--------|-----------|-----------|-------|
| **CLAUDE.md** | You (manually) | Main Claude + all agents | Project |
| **Auto-memory** | Main Claude (auto) | Main Claude only | Per-project per-user |
| **`/memory` command** | You (via editor) | Main Claude only | Per-project per-user |
| **Agent memory** | The agent itself | That specific agent only | Configurable (user/project/local) |

These systems are **complementary** — an agent reads both CLAUDE.md (project context) and its own memory (agent-specific knowledge).

---

## Practical Example

```yaml
---
name: api-developer
description: Implement API endpoints following team conventions
tools: Read, Write, Edit, Bash
model: sonnet
memory: project
skills:
  - api-conventions
  - error-handling-patterns
---

Implement API endpoints. Follow the conventions from your preloaded skills.
As you work, save architectural decisions and patterns to your memory.
```

This combines **skills** (static knowledge at startup) with **memory** (dynamic knowledge built over time).

---

## Tips

- **Prompt memory usage** — Include explicit instructions: `"Before starting, review your memory. After completing, update your memory with what you learned."`
- **Request memory checks** when invoking agents: `"Review this PR, and check your memory for patterns you've seen before."`
- **Choose the right scope** — `user` for cross-project, `project` for team-shared, `local` for personal

---

## Sources

- [Create custom subagents — Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
- [Manage Claude's memory — Claude Code Docs](https://code.claude.com/docs/en/memory)
- [Claude Code v2.1.33 Release Notes](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
