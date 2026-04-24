# Plugin Install vs. `install.sh` — Which One Should I Use?

> **TL;DR**: The Claude Code plugin loader currently surfaces only a subset of
> claude-forge's resources. If you want agents, hooks, rules, MCP servers, statusLine, or
> any of the `settings.json` behavior, use **`./install.sh`**. If you only need the slash
> commands and most skills, the `/plugin install` path works fine.

---

## 1. Why two install paths at all?

claude-forge ships a standard Claude Code plugin manifest
(`.claude-plugin/plugin.json` + `.claude-plugin/marketplace.json`) **and** a classic
symlink-based installer (`install.sh`). The two are intentional, because the Claude Code
plugin system is still maturing and its loader does not cover every resource type that
claude-forge distributes.

- **Plugin install** — official Claude Code surface. Lower friction (one slash command),
  updates via `/plugin update`, isolated to `~/.claude/plugins/cache/...`.
- **`install.sh`** — direct symlinks into `~/.claude/{agents,commands,hooks,rules,skills,
  scripts}`. Wires up everything the plugin loader skips, plus the CC CHIPS statusLine,
  shell aliases, and `settings.json` env blocks.

---

## 2. Resource-by-resource compatibility matrix

| Resource | `./install.sh` | `/plugin install` | Notes |
|----------|:-------------:|:----------------:|------|
| **Commands** (33) | ✅ Full | ✅ Full | Both paths register slash commands from `commands/`. |
| **Skills** (24)   | ✅ Full | ⚠️ Partial | Plugin-mode skills work, but QJC skills that reach into `~/.claude/rules/` or `~/.claude/agents/` assume the symlink layout. |
| **Agents** (11)   | ✅ Full | ❌ Not loaded | The plugin loader does not auto-register subagents from a plugin's `agents/` directory today. |
| **Hooks** (15 + 9 opt-in examples, 21 events) | ✅ Full | ❌ Not loaded | See [`hooks/hooks.json`](../hooks/hooks.json): "Claude Code does not support a separate hooks.json. Actual hook settings must be in settings.json." Plugin install does not merge a user's `settings.json`. |
| **Rules** (9)     | ✅ Full | ❌ Not loaded | Rules live under `~/.claude/rules/` and are loaded globally; the plugin loader does not surface them. |
| **MCP servers** (4, pinned) | ✅ Full | ❌ Not loaded | [`plugin.json`](../.claude-plugin/plugin.json) points `"mcpServers": "./mcp-servers.json"` but the loader does not act on that field. MCP servers come from `.mcp.json` / `mcp-servers.json`, wired by `install.sh`. |
| **statusLine** (CC CHIPS submodule) | ✅ (submodule opt-in) | ❌ Not loaded | Requires `git clone --recurse-submodules`, which is optional. `install.sh` detects missing submodules and skips statusLine wiring with a one-line hint. |
| **`settings.json` env / permissions** | ✅ Full | ❌ Not merged | Plugin install never touches the user's `settings.json`. |
| **Shell aliases** (`cc`, `ccr`) | ✅ | ❌ | Installed by `install.sh` via shell profile edits. |

> Legend: ✅ fully supported · ⚠️ partial or conditional · ❌ not delivered via this path.

---

## 3. Recommendation flowchart

```
Do you only need slash commands + some skills?
  ├── Yes → /plugin marketplace add sangrokjung/claude-forge
  │         /plugin install claude-forge
  │
  └── No (I also want agents / hooks / rules / MCP / statusLine)
          └── git clone https://github.com/sangrokjung/claude-forge.git
              cd claude-forge
              ./install.sh
```

For **most users**, `./install.sh` is the honest default. The plugin path is ideal for
read-only exploration or for sharing a small subset (e.g., someone else's CI that only
cares about a couple of slash commands).

---

## 4. Running both at the same time

The two paths are **not** mutually exclusive. You can:

1. Symlink everything with `./install.sh` (owns `~/.claude/{agents,hooks,rules,...}`), **and**
2. Add claude-forge as a plugin to get the `/plugin update` ergonomics for the Commands and
   Skills subset.

Because the plugin loader does not touch agents/hooks/rules/MCP/statusLine/settings.json,
the plugin path cannot conflict with the symlinks that `install.sh` created. Commands and
Skills exposed by both paths resolve to the same underlying source (repo-level files),
just via different loader mechanisms.

If you run both, remember to `git pull` the cloned repo **and** `/plugin update` —
otherwise the two copies can drift.

---

## 5. Frequently asked questions

### "I ran `/plugin install` but my agent doesn't show up."
Expected — agents are not loaded by the plugin loader. Install via `./install.sh`, which
creates `~/.claude/agents/*.md` symlinks.

### "Hooks are not firing after `/plugin install`."
Expected — hook settings must live in `~/.claude/settings.json` (or
`.claude/settings.json` inside a project), and plugin install never edits that file.
`./install.sh --upgrade` will merge claude-forge's hook catalog into your settings.

### "MCP servers from `mcp-servers.json` aren't connected."
Expected — the plugin loader ignores the `mcpServers` declaration in `plugin.json`.
Either (a) copy `mcp-servers.json` entries into your project's `.mcp.json`, or (b) run
`./install.sh`, which symlinks `mcp-servers.json` next to the `claude` binary's pickup
path.

### "How do I pin claude-forge to a specific release?"
Use `git clone --branch v3.0.1 --depth 1 ...` for the `install.sh` path. For the plugin
path, the marketplace manifest pins `plugins[0].version`; `/plugin update` will respect
published versions.

### "Is there any safe reason to prefer `/plugin install`?"
Yes — in ephemeral environments (CI runners, scratch laptops, classroom setups) where
you only need a small subset of commands/skills and you want easy teardown via
`/plugin uninstall`.

---

## 6. Scope of this document

This document describes the state of the Claude Code plugin loader **as observed on
2026-04-24**. If Anthropic extends the loader to cover agents / hooks / rules / MCP /
settings merging in a future release, this matrix will be updated accordingly.

Until then, the recommendation stands: **`./install.sh` for production use, `/plugin
install` for partial/ephemeral use.**

## 7. References

- [`README.md` — Quick Start](../README.md#-quick-start)
- [`docs/MARKETPLACE-SUBMISSION.md`](./MARKETPLACE-SUBMISSION.md)
- [`hooks/hooks.json`](../hooks/hooks.json) — own-repo confirmation that hooks.json is
  not a supported Claude Code format
- [`.claude-plugin/plugin.json`](../.claude-plugin/plugin.json) — plugin manifest
- [`.claude-plugin/marketplace.json`](../.claude-plugin/marketplace.json) — marketplace
  manifest
- [`install.sh`](../install.sh) — symlink installer
