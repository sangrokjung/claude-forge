# Claude Code: Global vs Project-Level Features

A comprehensive comparison of which Claude Code features are global-only (`~/.claude/`) versus which have both global and project-level (`.claude/`) equivalents.

<table width="100%">
<tr>
<td><a href="../">← Back to Claude Code Best Practice</a></td>
<td align="right"><img src="../!/claude-jumping.svg" alt="Claude" width="60" /></td>
</tr>
</table>

## Table of Contents

1. [Overview](#overview)
2. [Global-Only Features](#global-only-features)
3. [Dual-Scope Features](#dual-scope-features)
4. [Settings Precedence](#settings-precedence)
5. [Directory Structure Comparison](#directory-structure-comparison)
6. [Tasks System](#tasks-system)
7. [Agent Teams](#agent-teams)
8. [Design Principles](#design-principles)
9. [Sources](#sources)

---

## Overview

Claude Code uses a **scope hierarchy** where some features exist at both the global (`~/.claude/`) and project (`.claude/`) levels, while others are exclusively global. The design principle: things that are *personal state* or *cross-project coordination* live globally; things that are *team-shareable project config* can live at the project level.

- `~/.claude/` is your **user-level home** (global, all projects)
- `.claude/` inside a repo is your **project-level home** (scoped to that project)

---

## Global-Only Features

These live **only** under `~/.claude/` and cannot be scoped to a project:

| Feature | Location | Purpose |
|---------|----------|---------|
| **Tasks** | `~/.claude/tasks/` | Persistent task lists across sessions and agents |
| **Agent Teams** | `~/.claude/teams/` | Multi-agent coordination configs (experimental, Feb 2026) |
| **Auto Memory** | `~/.claude/projects/<hash>/memory/` | Claude's self-written learnings per project (personal, never shared) |
| **Credentials & OAuth** | System keychain + `~/.claude.json` | API keys, OAuth tokens (never in project files) |
| **Keybindings** | `~/.claude/keybindings.json` | Custom keyboard shortcuts |
| **MCP User Servers** | `~/.claude.json` (`mcpServers` key) | Personal MCP servers across all projects |
| **Preferences/Cache** | `~/.claude.json` | Theme, model, output style, session state |

---

## Dual-Scope Features

These exist at both levels, with **project-level taking precedence** over global:

| Feature | Global (`~/.claude/`) | Project (`.claude/`) | Precedence |
|---------|----------------------|---------------------|------------|
| **CLAUDE.md** | `~/.claude/CLAUDE.md` | `./CLAUDE.md` or `.claude/CLAUDE.md` | Project overrides global |
| **Settings** | `~/.claude/settings.json` | `.claude/settings.json` + `.claude/settings.local.json` | Project > Global |
| **Rules** | `~/.claude/rules/*.md` | `.claude/rules/*.md` | Project overrides |
| **Agents/Subagents** | `~/.claude/agents/*.md` | `.claude/agents/*.md` | Project overrides |
| **Commands** | `~/.claude/commands/*.md` | `.claude/commands/*.md` | Both available |
| **Skills** | `~/.claude/skills/` | `.claude/skills/` | Both available |
| **Hooks** | `~/.claude/hooks/` | `.claude/hooks/` | Both execute |
| **MCP Servers** | `~/.claude.json` (user scope) | `.mcp.json` (project scope) | Three scopes: local > project > user |

---

## Settings Precedence

User-writable settings apply in this override order (highest to lowest):

| Priority | Location | Scope | Version Control | Purpose |
|----------|----------|-------|-----------------|---------|
| 1 | Command line flags | Session | N/A | Single-session overrides |
| 2 | `.claude/settings.local.json` | Project | No (git-ignored) | Personal project-specific |
| 3 | `.claude/settings.json` | Project | Yes (committed) | Team-shared settings |
| 4 | `~/.claude/settings.local.json` | User | N/A | Personal global overrides |
| 5 | `~/.claude/settings.json` | User | N/A | Global personal settings |

Policy layer: `managed-settings.json` is organization-enforced and cannot be overridden by local files.

**Important**: `deny` rules have the highest safety precedence and cannot be overridden by lower-priority allow/ask rules.

---

## Directory Structure Comparison

### Global Scope (`~/.claude/`)

```
~/.claude/
├── settings.json              # User-level settings (all projects)
├── settings.local.json        # Personal overrides
├── CLAUDE.md                  # User memory (all projects)
├── agents/                    # User subagents (available to all projects)
│   └── *.md
├── rules/                     # User-level modular rules
│   └── *.md
├── commands/                  # User-level commands
│   └── *.md
├── skills/                    # User-level skills
│   └── */SKILL.md
├── tasks/                     # GLOBAL-ONLY: Task lists
│   └── {task-list-id}/
├── teams/                     # GLOBAL-ONLY: Agent team configs
│   └── {team-name}/
│       └── config.json
├── projects/                  # GLOBAL-ONLY: Per-project auto-memory
│   └── {project-hash}/
│       └── memory/
│           ├── MEMORY.md
│           └── *.md
├── keybindings.json           # GLOBAL-ONLY: Keyboard shortcuts
└── hooks/                     # User-level hooks
    ├── scripts/
    └── config/

~/.claude.json                 # GLOBAL-ONLY: MCP servers, OAuth, preferences, caches
```

### Project Scope (`.claude/`)

```
.claude/
├── settings.json              # Team-shared settings
├── settings.local.json        # Personal project overrides (git-ignored)
├── CLAUDE.md                  # Project memory (alternative to ./CLAUDE.md)
├── agents/                    # Project subagents
│   └── *.md
├── rules/                     # Project-level modular rules
│   └── *.md
├── commands/                  # Custom slash commands
│   └── *.md
├── skills/                    # Custom skills
│   └── {skill-name}/
│       ├── SKILL.md
│       └── supporting-files/
├── hooks/                     # Project-level hooks
│   ├── scripts/
│   └── config/
└── plugins/                   # Installed plugins

.mcp.json                      # Project-scoped MCP servers (repo root)
```

---

## Tasks System

Introduced in **Claude Code v2.1.16** (January 22, 2026), replacing the deprecated TodoWrite system.

### Storage

Tasks are stored at `~/.claude/tasks/` on the local filesystem (not in a cloud database). This makes task state auditable, version-controllable, and crash-recoverable.

### Tools

| Tool | Purpose |
|------|---------|
| **TaskCreate** | Create a new task with `subject`, `description`, and `activeForm` |
| **TaskGet** | Retrieve full details of a specific task by ID |
| **TaskUpdate** | Change status, set owner, add dependencies, or delete |
| **TaskList** | List all tasks with their current status |

### Task Lifecycle

```
pending  →  in_progress  →  completed
```

### Dependency Management

Tasks can block other tasks via `addBlockedBy`/`addBlocks`, creating dependency graphs that prevent premature execution.

### Multi-Session Collaboration

```bash
CLAUDE_CODE_TASK_LIST_ID=my-project-tasks claude
```

All sessions sharing the same ID see task updates in real-time, enabling parallel workstreams and session resumption.

### Key Differences from Old Todos

| Feature | Old Todos | New Tasks |
|---------|-----------|-----------|
| Scope | Single session | Cross-session, cross-agent |
| Dependencies | None | Full dependency graph |
| Storage | In-memory only | File system (`~/.claude/tasks/`) |
| Persistence | Lost on session end | Survives restarts and crashes |
| Multi-session | Not possible | Via `CLAUDE_CODE_TASK_LIST_ID` |

---

## Agent Teams

Announced **February 5, 2026** as an experimental feature. Agent Teams allow multiple Claude Code sessions to coordinate on shared work.

### Enabling

```json
// In ~/.claude/settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

### Configuration

Team configs live at `~/.claude/teams/{team-name}/` and support modes:

| Mode | Description | Requirements |
|------|-------------|--------------|
| **In-process** (default) | All teammates run inside your terminal | None |
| **Split panes** | Each teammate gets its own pane | tmux or iTerm2 (not VS Code terminal) |

---

## Design Principles

The global-only vs dual-scope split follows a clear pattern:

| Category | Scope | Rationale |
|----------|-------|-----------|
| **Coordination state** (tasks, teams) | Global-only | Needs to persist beyond any single project |
| **Security state** (credentials, OAuth) | Global-only | Prevents accidental commits to version control |
| **Personal learning** (auto-memory) | Global-only | User-specific, not team-shareable |
| **Input preferences** (keybindings) | Global-only | User muscle memory, not project-specific |
| **Configuration** (settings, rules, agents) | Both levels | Teams need to share project-specific behavior |
| **Workflow definitions** (commands, skills) | Both levels | Can be personal or team-shared |

Auto-memory (`~/.claude/projects/<hash>/memory/`) is a notable hybrid: it's *about* a specific project but stored *globally* because it represents personal learning rather than team-shareable configuration.

---

## Sources

- [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings)
- [Orchestrate Teams of Claude Code Sessions](https://code.claude.com/docs/en/agent-teams)
- [What are Tasks in Claude Code - ClaudeLog](https://claudelog.com/faqs/what-are-tasks-in-claude-code/)
- [Claude Code Task Management - ClaudeFast](https://claudefa.st/blog/guide/development/task-management)
- [Claude Code Tasks Update - VentureBeat](https://venturebeat.com/orchestration/claude-codes-tasks-update-lets-agents-work-longer-and-coordinate-across)
- [Where Are Claude Code Global Settings - ClaudeLog](https://claudelog.com/faqs/where-are-claude-code-global-settings/)
- [Claude Opus 4.6 Agent Teams - VentureBeat](https://venturebeat.com/technology/anthropics-claude-opus-4-6-brings-1m-token-context-and-agent-teams-to-take)
- [How to Set Up Claude Code Agent Teams (Full Walkthrough) - r/ClaudeCode](https://www.reddit.com/r/ClaudeCode/comments/1qz8tyy/how_to_set_up_claude_code_agent_teams_full/)
- [Anthropic replaced Claude Code's old 'Todos' with Tasks - r/ClaudeAI](https://www.reddit.com/r/ClaudeAI/comments/1qkjznp/anthropic_replaced_claude_codes_old_todos_with/)
