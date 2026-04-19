# Migrating from v2.1 to v3.0

> **TL;DR** — v3.0 is a **net-additive release** for most users. The only breaking change is the MCP default set (6 → 3), and the 3 removed servers are all one-paste-away restorable from `mcp-servers.optional.json`. Subagents, hooks, skills, commands, and `settings.json` all gain new capabilities without touching existing behavior. Plan for a **5-minute upgrade**, not a migration project.

## 1-Minute Upgrade

```bash
cd path/to/claude-forge
git pull
./install.sh --upgrade
```

That's it for the happy path. `install.sh --upgrade` (T7) detects your v2.1 layout, backs up the relevant symlinks under `~/.claude/.backup-<timestamp>/`, updates `mcp-servers.json` / `settings.json` / frontmatter on a best-effort basis, and leaves your user-authored files alone.

If you customized `mcp-servers.json` or `settings.json` by hand, see [Step 2](#step-2-mcp-migration) and [Step 6](#step-6-settingsjson) below before re-running.

## What Changed At a Glance

| Area | v2.1 | v3.0 | Breaking? |
|------|------|------|-----------|
| MCP default servers | 6 (`memory`, `exa`, `github`, `fetch`, `playwright`, `context7`) | 3 (`playwright`, `context7`, `jina-reader`) + `mcp-servers.optional.json` | **Yes** (restorable) |
| Hooks events | 5 wired (`PreToolUse`, `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `Stop`) | 21 catalogued, 9 opt-in examples in `hooks/examples/` | No (additive) |
| Subagent frontmatter | 5 fields (`name`, `description`, `tools`, `model`, `color`) | 13 fields — 10 optional (`isolation`, `background`, `maxTurns`, `skills`, `mcpServers`, `effort`, `hooks`, `permissionMode`, `disallowedTools`, `memory`) | No (additive) |
| Skills vs Commands | Undocumented, 8 directory-form entries under `commands/` | Hybrid policy documented (`docs/SKILLS-VS-COMMANDS.md`); 8 dirs moved to `skills/` with 1-year symlinks | No (symlinks preserved) |
| CLAUDE.md | No starter template | `setup/CLAUDE.md.template` (≤ 60 lines) + `docs/CLAUDE-MD-GUIDE.md` (load hierarchy, @import, 200-line rule) | No (additive) |
| settings.json | Basic perms + hooks | Adds `tui`, `disableSkillShellExecution`, `enabledMcpjsonServers` at the top level | No (fields default to v2.1 behavior when absent) |
| MCP allow-list | `mcp__memory`, `mcp__exa`, `mcp__github`, `mcp__fetch` allowed | Replaced by `mcp__playwright`, `mcp__context7`, `mcp__jina-reader` | Yes (mirrors MCP change) |

Everything below walks through these rows in install order.

## Detailed Migration Steps

### Step 1: Back up current setup

Before any change, snapshot `~/.claude/` so you can roll back in 30 seconds if anything misfires.

```bash
# 1. Snapshot the live config
cp -R ~/.claude ~/.claude.bak-$(date +%Y%m%d-%H%M)

# 2. Confirm git tree is clean inside claude-forge
cd path/to/claude-forge
git status   # should be empty or only expected WIP
git branch   # confirm you are ready to pull
```

`install.sh --upgrade` also writes its own backup under `~/.claude/.backup-<timestamp>/`, but a manual copy is cheap insurance for anything the installer does not touch (local hooks, handcrafted agents, personal skills).

### Step 2: MCP migration

Full recipes live in [`docs/MCP-MIGRATION.md`](docs/MCP-MIGRATION.md). The short version:

1. `mcp-servers.json` now ships **3 servers** only: `playwright`, `context7`, `jina-reader`.
2. The 4 servers removed from defaults (`memory`, `exa`, `github`, `fetch`) are in [`mcp-servers.optional.json`](mcp-servers.optional.json) together with 4 extras (`time`, `sequential-thinking`, `supabase`, `chrome-devtools`).
3. To restore any of them, copy its entry into `mcp-servers.json` under `"servers"`, then re-run `./install.sh --upgrade`.
4. The rationale for each removal (Auto Memory, native `WebSearch`, `gh` CLI, `jina-reader`) is in `docs/MCP-MIGRATION.md`.

If you use the `memory` / `exa` / `github` / `fetch` servers in automations, copy them back **before** Step 6 so the `enabledMcpjsonServers` hint matches reality.

### Step 3: Hooks (optional)

Hook scripts you already installed **keep working**. v3.0 adds a **catalog of 21 events** (`hooks/README.md`) and ships **9 shell examples** under `hooks/examples/`:

```
hooks/examples/
├── post-compact.sh.example
├── post-tool-use-failure.sh.example
├── pre-compact.sh.example
├── stop-failure.sh.example
├── subagent-start.sh.example
├── subagent-stop.sh.example
├── task-created.sh.example
├── worktree-create.sh.example
└── worktree-remove.sh.example
```

To enable any of them:

```bash
# 1. Copy the example and rename (drop .example)
cp hooks/examples/stop-failure.sh.example hooks/stop-failure.sh
chmod +x hooks/stop-failure.sh

# 2. Register it in ~/.claude/settings.json under the matching event
#    See hooks/README.md for the exact block shape per event.
```

Default `settings.json` still wires only the 5 v2.1 hooks (`PreToolUse`, `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `Stop`, plus `TaskCompleted`). Nothing new fires until you opt in, so upgrading does not change runtime behavior.

### Step 4: Subagent frontmatter (optional)

v2.1 agents use 5 fields. v3.0 adds **10 optional fields** (full list in `docs/AGENT-FRONTMATTER-V2.md`, authored in T2):

```yaml
---
name: code-reviewer
description: Expert code review specialist...
tools: ["Read", "Grep", "Glob", "Bash"]
model: opus
memory: project
color: blue
# v3.0 optional fields — uncomment when needed
# isolation: worktree       # isolate agent work in a git worktree
# background: true          # run in background without blocking
# maxTurns: 20              # cap conversation length
# skills: [code-review]     # preload skills
# mcpServers: [context7]    # scoped MCP access
# effort: max               # deep reasoning
# hooks:                    # agent-specific hooks
#   PreToolUse: [...]
# permissionMode: acceptEdits
# disallowedTools: [WebFetch]
---
```

Existing v2.1 frontmatter is **fully supported**. There is no deprecation. Add the new fields only where they clearly help — `isolation: worktree` for destructive refactors, `maxTurns` for runaway loops, `effort: max` for deep reviews. See T2 reference for real-world recipes per agent.

### Step 5: Skills/Commands clean-up

Eight directory-form entries that always behaved as skills have moved from `commands/` to `skills/`. The old paths are kept as **symlinks for one year** (removal target: **2027-04-01**), so nothing breaks on day one.

| v2.1 path | v3.0 path |
|-----------|-----------|
| `commands/debugging-strategies/` | `skills/debugging-strategies/` |
| `commands/dependency-upgrade/` | `skills/dependency-upgrade/` |
| `commands/evaluating-code-models/` | `skills/evaluating-code-models/` |
| `commands/evaluating-llms-harness/` | `skills/evaluating-llms-harness/` |
| `commands/extract-errors/` | `skills/extract-errors/` |
| `commands/security-compliance/` | `skills/security-compliance/` |
| `commands/stride-analysis-patterns/` | `skills/stride-analysis-patterns/` |
| `commands/summarize/` | `skills/summarize/` |

The policy that drove these moves is documented in [`docs/SKILLS-VS-COMMANDS.md`](docs/SKILLS-VS-COMMANDS.md). Heuristic: if a directory has a `references/` subtree and loads as reusable knowledge, it is a skill; if it is a flat `.md` with side effects the user times, it is a command.

If you reference these paths in personal scripts or hooks, switch to the new `skills/` path at your leisure — the symlinks buy you time.

### Step 6: settings.json

v3.0 `settings.json` adds **three top-level fields** on top of v2.1:

```json
{
  "tui": true,
  "disableSkillShellExecution": false,
  "enabledMcpjsonServers": ["playwright", "context7", "jina-reader"]
}
```

Meaning:

- **`tui`** — opts into the 2026 terminal UI (richer statusline, inline skill hints). Omit or set `false` to keep the v2.1 CLI rendering. Backward-compatible default.
- **`disableSkillShellExecution`** — when `true`, skills cannot spawn subshells. Leave `false` unless your org policy requires it; several shipped skills (`/build-fix`, `/e2e`, `/auto`) need shell access.
- **`enabledMcpjsonServers`** — explicit allowlist for which `mcp-servers.json` entries actually boot. Must match (or subset) the `"servers"` keys. When you restore `memory` / `exa` in Step 2, add it here too.

The `permissions.allow` block also changed: `mcp__memory`, `mcp__exa`, `mcp__github`, `mcp__fetch` were **removed**, and `mcp__playwright` was **added**. If you restore old MCP servers, re-add their `mcp__<server>__*` allow entry so the tool search does not prompt every call.

## Compatibility Timeline

| Item | Deprecation status | Sunset |
|------|--------------------|--------|
| Symlinks at `commands/<skill>/` pointing to `skills/<skill>/` | Kept for 1 year, warning in `show-setup` after 2026-10 | **2027-04-01** |
| v2.1 mcp-servers defaults (`memory`, `exa`, `github`, `fetch`) | Removed from defaults, restorable from `mcp-servers.optional.json` | No sunset — optional catalog is maintained |
| v2.1 5-field agent frontmatter | Fully supported, no plans to deprecate | No sunset |
| v2.1 hooks event set (5 wired events) | Still the default, new events strictly opt-in | No sunset |
| `WebFetch` in `permissions.allow` | Already blocked in v2.1 via `deny`, unchanged | N/A |
| v2.1 `settings.json` minus the 3 new fields | Fully valid, new fields default to v2.1 semantics when absent | No sunset |

Rule of thumb: **v3.0 tries very hard not to break v2.1 setups**. Only the MCP default list is a material break, and restoring the old set is 2 lines of JSON per server plus a re-install.

## Rollback

If something misbehaves after upgrading, full rollback is three commands.

```bash
# 1. Restore the v2.1 claude-forge tree
cd path/to/claude-forge
git checkout v2.1.0        # or the tag you upgraded from

# 2. Restore the ~/.claude snapshot from Step 1
rm -rf ~/.claude
mv ~/.claude.bak-YYYYMMDD-HHMM ~/.claude

# 3. Reinstall the v2.1 symlinks
./install.sh
```

If you only want to revert one piece (say, MCP defaults), edit `mcp-servers.json` by hand and re-run `./install.sh --upgrade`. The installer is idempotent and will not overwrite user-authored files.

## FAQ

**Q1. I never touched my `settings.json`. Will `install.sh --upgrade` rewrite it?**
No. The installer only inserts the 3 new v3.0 top-level fields if they are missing, and only updates `permissions.allow` for MCP tool names that v2.1 also managed. Hand-edited keys are preserved.

**Q2. My automations pipe through `mcp__github__*`. What now?**
Copy the `github` entry from `mcp-servers.optional.json` into `mcp-servers.json`, re-add `"mcp__github__*"` to `permissions.allow` and the server name to `enabledMcpjsonServers`, then `./install.sh --upgrade`. Your existing tool calls resume working.

**Q3. I want Auto Memory **and** the old `memory` MCP in parallel.**
Supported. Auto Memory lives at `~/.claude/projects/<hash>/memory/`; adding the `memory` MCP back simply gives you a **team-shared knowledge graph** on top. They do not conflict.

**Q4. Will my v2.1 agent YAML still parse?**
Yes. The 10 new fields are all optional. If the key is absent, the harness falls back to v2.1 semantics (no isolation, foreground, unlimited turns, agent-visible default tool-set, default model effort, no agent-scoped hooks).

**Q5. The symlinks at `commands/<skill>/` will vanish in 2027-04. What do I update?**
Any personal script, hook, or doc that hard-codes `~/.claude/commands/debugging-strategies/` → switch to `~/.claude/skills/debugging-strategies/`. `show-setup` will start flagging outdated references around 2026-10 so you have a warning window.

**Q6. Does `disableSkillShellExecution: true` break the shipped skills?**
Some of them, yes. `/build-fix`, `/e2e`, `/auto`, `/handoff-verify`, `/quick-commit` all run shell commands. If your org mandates the flag, run those workflows as direct `Bash` tool calls from the main conversation instead of through the skill wrappers.

**Q7. Can I adopt v3.0 gradually — MCP first, hooks later?**
Yes. Each step above is independent. The only hard coupling is "if you add an MCP server back to `mcp-servers.json`, also add it to `enabledMcpjsonServers` and `permissions.allow`". Everything else can land on its own schedule.

## References

- [`docs/MCP-MIGRATION.md`](docs/MCP-MIGRATION.md) — per-server replacement recipes (memory / exa / github / fetch)
- [`docs/SKILLS-VS-COMMANDS.md`](docs/SKILLS-VS-COMMANDS.md) — hybrid policy driving Step 5
- [`docs/AGENT-FRONTMATTER-V2.md`](docs/AGENT-FRONTMATTER-V2.md) — Step 4 field reference (T2)
- [`docs/CLAUDE-MD-GUIDE.md`](docs/CLAUDE-MD-GUIDE.md) — 200-line rule, load hierarchy, @import
- [`hooks/README.md`](hooks/README.md) — 21-event catalog and matcher schema
- [`mcp-servers.optional.json`](mcp-servers.optional.json) — catalog of add-back servers
- [`setup/CLAUDE.md.template`](setup/CLAUDE.md.template) — starter CLAUDE.md for new projects
- [한국어 버전](MIGRATION.ko.md)
