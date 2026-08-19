# Migrating from v3.1 to v4.0

> **TL;DR** — v4.0 is a **net-additive release**, same as v3.0 was. Nothing existing is removed or
> renamed. The new pieces (adversarial verification loop, reliability pack, debugging escalation
> chain, task-grade routing, Korean prose quality guardrails) are new files, new agents, and new
> hooks — none of them change how your existing commands, skills, or hooks behave. Plan for a
> **5-minute upgrade**.

## 1-Minute Upgrade

```bash
cd path/to/claude-forge
git pull
./install.sh --upgrade
```

`install.sh --upgrade` backs up your existing `~/.claude/` symlinks, then refreshes every
directory the installer manages — including the two new ones this release adds, `libs/` and
`reference/` (see [Step 2](#step-2-new-directories-libs-and-reference) below).

## What Changed At a Glance (v3.1 → v4.0)

| Area | v3.1 | v4.0 | Breaking? |
|------|------|------|-----------|
| Agents | 11 | 16 (+5: `adversarial-reviewer`, `skeptical-auditor`, `systematic-debugger`, `rca-debugger`, `escalation-fixer`) | No (additive) |
| Commands | 34 | 35 (+1: `/workflow-classify`) | No (additive) |
| Skills | 26 | 32 (+6: `humanize-korean`, `korean-character-count`, `korean-spell-check`, `relay`, `review-loop`, `systematic-debugging`) | No (additive) |
| Hooks | 15 | 21 (+6, see below) | No (additive) |
| Rules | 10 | 14 (+4: `adversarial-review`, `api-error-recovery`, `korean-writing-quality`, `task-grade-routing`) | No (additive) |
| Installed directories | 8 (`agents rules commands scripts skills hooks libs cc-chips cc-chips-custom`) | 9 (+`reference`) | No (additive — see below) |
| Hooks events wired in `settings.json` | `PreToolUse`, `SessionStart`, `UserPromptSubmit`, `PostToolUse`, `Stop`, `TaskCompleted` | + `StopFailure`, `PreCompact`, `SessionStart` (matcher `compact`) | No (additive) |
| Hook message text | Mixed Korean/English across hooks | New v4.0 hooks are **English-only** — see [Step 5](#step-5-hook-message-text-is-now-english) | No (cosmetic — existing hooks unchanged) |

### Step 1: New hook events wired

v4.0 registers three events in `settings.json` that were previously only catalogued (opt-in
examples), not wired by default:

| Event | Matcher | Hook | Purpose |
|---|---|---|---|
| `StopFailure` | — | `api-error-auto-resume.sh` | Classify a session-ending API error, schedule an unattended resume |
| `PreCompact` | — | `pre-compact-snapshot.sh` | Snapshot the `relay` skill's baton pointer before context compaction |
| `SessionStart` | `compact` | `post-compact-restore.sh` | Restore that pointer into the fresh session, exactly once |

None of these fire unless their trigger condition happens (a `StopFailure` event, or a
`/compact`), so a clean upgrade has zero behavioral change until you hit one of those situations.
Full wiring guide: [`docs/RELIABILITY.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/RELIABILITY.md).

### Step 2: New directories (`libs/` and `reference/`)

Two directories are now part of the installer's managed set:

- **`libs/`** — ships `hook-guard.sh`, a shared cooldown/token-guard library other hooks
  (`context-sync-suggest.sh`, `api-error-auto-resume.sh`) `source` if present. Every consumer
  guards the `source` line (`[ -r ~/.claude/libs/hook-guard.sh ] && source ...`), so a pre-upgrade
  install missing this directory degrades gracefully rather than erroring.
- **`reference/`** — was already shipped in v3.0 (`agent-schema.json`), but was not in the
  installer's directory list; v4.0 adds it explicitly (it also now carries
  `ai-tell-taxonomy.md`, the Korean AI-tell classification SSOT).

If you're re-running `./install.sh --upgrade` from a v3.1 checkout, both directories are picked
up automatically — no manual step needed.

### Step 3: Opt-in pre-commit secret guard

New in v4.0, and **not wired automatically** — this protects git commits in whichever repo you
point it at, separately from the Claude Code hooks above:

```bash
bash scripts/install-precommit.sh              # installs into the repo containing $PWD
bash scripts/install-precommit.sh --all ~/code  # installs into every git repo under a tree
```

Blocks commits containing shapes that look like live credentials (`sk-...`, `ghp_...`,
AWS `AKIA...`, Supabase `sbp_...`, and more), staged `.env` files, and unusually large files.
Idempotent — re-running skips an already-installed guard. See [`docs/RELIABILITY.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/RELIABILITY.md).

### Step 4: `FORGE_NOTIFY_CMD` contract (new)

The new `api-error-auto-resume.sh` / `api-error-resume-runner.sh` pair can notify you when it
self-disables or completes an unattended resume. Unset (the default), it's a silent no-op. Set
it to **one executable path** (not a command line):

```bash
export FORGE_NOTIFY_CMD="$HOME/bin/forge-notify"   # your own script, called as: forge-notify "<title>" "<message>"
```

Nothing in this release ships a reference implementation of that script — write your own, or
leave it unset. Full contract, including why it must be a single executable and not a command
line: [`rules/api-error-recovery.md`](rules/api-error-recovery.md).

### Step 5: Hook message text is now English

All hooks shipped in v4.0 (`api-error-auto-resume.sh`, `loop-detection.sh`, `auto-verify-fix.sh`,
`pre-compact-snapshot.sh`, `post-compact-restore.sh`, `emdash-slop-guard.sh`, and everything under
`scripts/` for the same features) emit English-only log lines, prompts, and `additionalContext`
messages. This is a **product decision for this release**, not a partial translation — those
surfaces are read by the model and by international users, so English is the answer regardless of
which language you work in. Pre-existing hooks from v3.x keep whatever language they already used
(some are Korean) — this release does not retroactively translate them.

### Step 6: Kill switches for the new reliability pack

Every new always-on piece has an off switch:

```bash
# API-error auto-resume — the highest-risk new default-on feature
touch ~/.claude/cache/auto-resume/DISABLED    # every session on this machine
export CLAUDE_AUTO_RESUME_DISABLED=1          # this shell only
export CLAUDE_AUTO_RESUME_TAKEOVER=0          # keep resume, but never kill+take over a live terminal session

# Doom-loop / edit-time verify — deregister from settings.json's PostToolUse array,
# or reset loop-detection's counters without disabling it:
rm /tmp/claude-loop-detect-*.jsonl

# Pre-commit secret guard (opt-in, so "off" is just never installing it, or per-repo):
rm .git/hooks/pre-commit
```

Full reference for every kill switch and environment variable in the pack:
[`docs/RELIABILITY.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/RELIABILITY.md) and [`rules/api-error-recovery.md`](rules/api-error-recovery.md).

### Platform note

The reliability pack (Step 6) was developed and tested on macOS. Portability was addressed at the
source level for Linux/WSL, but the **takeover** (kill + headless-resume a live non-tmux session)
and **tmux injection** paths were not exercised on a real Linux/WSL host in this release. See the
platform matrix in [`docs/RELIABILITY.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/RELIABILITY.md) before relying on those two paths
for an unattended long-running job on Linux.

### References (v3.1 → v4.0)

- [`docs/RELIABILITY.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/RELIABILITY.md) — wiring guide for the whole reliability pack (S1–S5)
- [`docs/VERIFICATION-LOOP.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/VERIFICATION-LOOP.md) — the adversarial verification loop, worked through on this release's own PRs
- [`rules/adversarial-review.md`](rules/adversarial-review.md) — when the verification loop is mandatory
- [`rules/api-error-recovery.md`](rules/api-error-recovery.md) — full auto-resume contract, verdicts, caps, env vars
- [`rules/korean-writing-quality.md`](rules/korean-writing-quality.md) — Korean prose quality guardrails
- [`rules/task-grade-routing.md`](rules/task-grade-routing.md) — `/workflow-classify` sizing and routing
- [한국어 버전](MIGRATION.ko.md)

---

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

Full recipes live in [`docs/MCP-MIGRATION.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/MCP-MIGRATION.md). The short version:

1. `mcp-servers.json` now ships **3 servers** only: `playwright`, `context7`, `jina-reader`.
2. The 4 servers removed from defaults (`memory`, `exa`, `github`, `fetch`) are in [`mcp-servers.optional.json`](mcp-servers.optional.json) together with 4 extras (`time`, `sequential-thinking`, `supabase`, `chrome-devtools`).
3. To restore any of them, copy its entry into `mcp-servers.json` under `"servers"`, then re-run `./install.sh --upgrade`.
4. The rationale for each removal (Auto Memory, native `WebSearch`, `gh` CLI, `jina-reader`) is in `docs/MCP-MIGRATION.md`.

If you use the `memory` / `exa` / `github` / `fetch` servers in automations, copy them back **before** Step 6 so the `enabledMcpjsonServers` hint matches reality.

### Step 2.5: Review five agents that historically used removed MCP tools

v2.1 shipped five agents whose `Tool_Usage` section directly referenced `mcp__exa__*` or `mcp__memory__*`. In v3.0 these references have been **rewritten to built-in tools with the MCP as an optional fallback**, but if you previously customized any of the five, re-check your local copy:

| Agent | Historical tool | v3.0 replacement |
|-------|-----------------|-------------------|
| `agents/security-reviewer.md` | `mcp__exa__web_search_exa` | Built-in `WebSearch` (Exa optional) |
| `agents/architect.md` | `mcp__exa__web_search_exa` | Built-in `WebSearch` (Exa optional) |
| `agents/refactor-cleaner.md` | `mcp__memory__*` | Auto Memory (`~/.claude/projects/<project>/memory/`) or plain log; memory MCP optional |
| `agents/doc-updater.md` | `mcp__memory__*` | Auto Memory or `git log`; memory MCP optional |
| `agents/database-reviewer.md` | `mcp__memory__*` | Auto Memory or migration files; memory MCP optional |

**If you kept the v2.1 wording in a private fork**: either (a) pull the v3.0 copy and redo your customization, or (b) restore the matching MCP server from `mcp-servers.optional.json` (Step 2) so the old tool name resolves again.

**If you use the agents as shipped**: nothing to do. v3.0 auto-falls back to the built-in tool without any manual MCP setup.

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

The policy that drove these moves is documented in [`docs/SKILLS-VS-COMMANDS.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/SKILLS-VS-COMMANDS.md). Heuristic: if a directory has a `references/` subtree and loads as reusable knowledge, it is a skill; if it is a flat `.md` with side effects the user times, it is a command.

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
Supported. Auto Memory lives at `~/.claude/projects/<project>/memory/`; adding the `memory` MCP back simply gives you a **team-shared knowledge graph** on top. They do not conflict.

**Q4. Will my v2.1 agent YAML still parse?**
Yes. The 10 new fields are all optional. If the key is absent, the harness falls back to v2.1 semantics (no isolation, foreground, unlimited turns, agent-visible default tool-set, default model effort, no agent-scoped hooks).

**Q5. The symlinks at `commands/<skill>/` will vanish in 2027-04. What do I update?**
Any personal script, hook, or doc that hard-codes `~/.claude/commands/debugging-strategies/` → switch to `~/.claude/skills/debugging-strategies/`. `show-setup` will start flagging outdated references around 2026-10 so you have a warning window.

**Q6. Does `disableSkillShellExecution: true` break the shipped skills?**
Some of them, yes. `/build-fix`, `/e2e`, `/auto`, `/handoff-verify`, `/quick-commit` all run shell commands. If your org mandates the flag, run those workflows as direct `Bash` tool calls from the main conversation instead of through the skill wrappers.

**Q7. Can I adopt v3.0 gradually — MCP first, hooks later?**
Yes. Each step above is independent. The only hard coupling is "if you add an MCP server back to `mcp-servers.json`, also add it to `enabledMcpjsonServers` and `permissions.allow`". Everything else can land on its own schedule.

## References

- [`docs/MCP-MIGRATION.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/MCP-MIGRATION.md) — per-server replacement recipes (memory / exa / github / fetch)
- [`docs/SKILLS-VS-COMMANDS.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/SKILLS-VS-COMMANDS.md) — hybrid policy driving Step 5
- [`docs/AGENT-FRONTMATTER-V2.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/AGENT-FRONTMATTER-V2.md) — Step 4 field reference (T2)
- [`docs/CLAUDE-MD-GUIDE.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/CLAUDE-MD-GUIDE.md) — 200-line rule, load hierarchy, @import
- [`hooks/README.md`](hooks/README.md) — 21-event catalog and matcher schema
- [`mcp-servers.optional.json`](mcp-servers.optional.json) — catalog of add-back servers
- [`setup/CLAUDE.md.template`](setup/CLAUDE.md.template) — starter CLAUDE.md for new projects
- [한국어 버전](MIGRATION.ko.md)
