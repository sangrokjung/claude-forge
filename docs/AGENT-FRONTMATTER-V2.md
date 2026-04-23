# Agent Frontmatter v2 — claude-forge v3.0

This document describes the subagent YAML frontmatter schema introduced in claude-forge v3.0. It aligns with the Anthropic 2026 subagent definition and extends the v1 schema (name/description/tools/model/memory/color) with nine optional fields that unlock isolation, background execution, scoped MCP access, per-agent hooks, and more.

> **Reading guide:** The five v1 fields remain **required or strongly recommended** for every agent. The nine v2 fields are **strictly optional** — leave them out (or keep them commented) unless you have a concrete reason to enable one.

## Field reference

| Field | Purpose | When to use | Example value | Since |
|-------|---------|-------------|---------------|-------|
| `name` | Unique agent identifier. Must match the file name. | Always. | `architect` | v1 |
| `description` | One-liner that tells the router when to invoke this agent. Use "PROACTIVELY" / "MUST BE USED" to nudge auto-activation. | Always. | `Software architecture specialist…` | v1 |
| `tools` | Whitelist of built-in tools the agent may call. Omit to inherit all tools. | Always (explicit is safer). | `["Read", "Grep", "Glob"]` | v1 |
| `model` | Preferred model tier: `opus`, `sonnet`, `haiku`, or `inherit`. | Always. | `opus` | v1 |
| `memory` | Memory scope: `project` (shared with main session), `agent` (dedicated folder under `~/.claude/agent-memory/{name}/`), or `none`. | Always. | `project` | v1 |
| `color` | Terminal label color. Cosmetic only. | Optional. | `blue` | v1 |
| `isolation` | Run the agent in a **git worktree** (`worktree`) or in the current tree (`inline`, default). Prevents file conflicts during parallel work. | Verification, parallel refactors, long-running cleanups. | `worktree` | v3.0 |
| `background` | Run the agent asynchronously without blocking the parent session. Results arrive via notification. | Slow verifications, batch processing. | `true` | v3.0 |
| `maxTurns` | Hard cap on conversation turns before the agent auto-stops. | Open-ended exploration agents that otherwise loop. | `20` | v3.0 |
| `skills` | Pre-load these skills into the agent's context at spawn time. | Agents that always need the same skill(s) available. | `[security-review]` | v3.0 |
| `mcpServers` | Restrict the agent to a subset of MCP servers. Default is "all configured servers." | Sandboxing (e.g. DB agent sees only `supabase`). | `[context7]` | v3.0 |
| `effort` | Reasoning effort: `low`, `medium`, `high`, or `max`. Maps to the model's thinking budget. | Deep architectural or security reasoning. | `max` | v3.0 |
| `hooks` | Agent-local hook definitions (PreToolUse, PostToolUse, Stop, etc.). Overlay on top of global hooks in `settings.json`. | Enforce per-agent guardrails without polluting global settings. | see example | v3.0 |
| `permissionMode` | Permission model for this agent only: `default`, `acceptEdits`, `bypassPermissions`, `plan`. | Trusted agents that should not prompt on every edit. | `acceptEdits` | v3.0 |
| `disallowedTools` | Explicit blocklist applied on top of `tools`. | Subtract dangerous tools from an inherited toolset. | `[Bash, WebFetch]` | v3.0 |

## Example: before and after

**v1 (still valid):**

```yaml
---
name: architect
description: Software architecture specialist…
tools: ["Read", "Grep", "Glob"]
model: opus
memory: project
color: blue
---
```

**v2 extended (architect.md in v3.0):**

```yaml
---
name: architect
description: Software architecture specialist…
tools: ["Read", "Grep", "Glob"]
model: opus
memory: project
color: blue
effort: max                # NEW — deep reasoning for architecture trade-offs
# v3.0 optional fields (uncomment when needed):
# isolation: worktree
# background: true
# maxTurns: 20
# skills: [arch-review]
# mcpServers: [context7]
# hooks:
#   PreToolUse: [...]
# permissionMode: acceptEdits
# disallowedTools: [WebFetch]
---
```

The commented block acts as a **self-documenting menu**. To enable a field, uncomment the line, fill in the value, and save. No template surgery required.

## Migration policy for v3.0

- The v1 schema is **fully backward compatible**. Old agents continue to work unchanged.
- Only two built-in agents enable a v2 field in v3.0:
  - `verify-agent.md` sets `isolation: worktree` so pipeline verification runs in its own worktree.
  - `architect.md` sets `effort: max` so architectural reasoning gets the largest thinking budget.
- The remaining nine built-in agents carry the **commented v3.0 block** only. This signals support without changing behavior.

## Validation

The v3.0 CI job (`.github/workflows/validate.yml`) lints every `agents/*.md` file against `reference/agent-schema.json` (JSON Schema draft-07). Unknown top-level keys produce warnings, not errors — this keeps future Anthropic additions from breaking CI before we can update the schema.

## Verification Status (as of 2026-04-18)

Not every v3.0 field is identically documented on the public Anthropic spec page. Based on an independent review against the official docs + release notes:

| Field | Official spec page | Notes |
|-------|--------------------|-------|
| `name`, `description`, `tools`, `model`, `memory`, `color` | ✅ Confirmed | v1 fields, stable. |
| `isolation` | ✅ Confirmed | Documented on the subagents page with `worktree` enum. |
| `mcpServers` | ✅ Confirmed | Documented on the subagents / MCP page. |
| `maxTurns` | ✅ Confirmed | Referenced in agent SDK docs. |
| `hooks` | ✅ Confirmed | Per-agent hook overlay documented. |
| `permissionMode` | ✅ Confirmed | Enum documented on the settings / permissions page. |
| `disallowedTools` | ✅ Confirmed | Mentioned as counterpart to `tools`. |
| `effort` | ⚠️ **Unverified** | Referenced in roadmap / issue threads, not yet on the public schema page. Kept as `effort: max` only on `architect.md` — safe to remove if it produces warnings on your Claude Code version. |
| `background` | ⚠️ **Unverified** | Scheduled but not yet on the public schema page. Kept as a **commented example** on all 11 agents. |
| `skills` (preload) | ⚠️ **Unverified** | Mentioned in skills / agent-skills blog posts, not yet on the subagent schema page. Kept as a **commented example** on all 11 agents. |

The 3 "Unverified" fields are **opt-in only**: they appear as commented-out examples in each agent file. Uncomment a field only after confirming it is supported in your running Claude Code release (`claude --version` + the docs page for that version). CI (`validate.yml`) treats unknown fields as warnings, not errors, so your agent files will not break if Anthropic renames or drops one of these fields later.

## References

- Anthropic subagents documentation: <https://docs.claude.com/en/docs/claude-code/sub-agents>
- Anthropic hooks reference: <https://docs.claude.com/en/docs/claude-code/hooks>
- Anthropic MCP guide: <https://docs.claude.com/en/docs/claude-code/mcp>
- claude-forge JSON Schema: `reference/agent-schema.json`
- Related docs: `docs/SKILLS-VS-COMMANDS.md`, `docs/WORKFLOW-RECIPES.md`
