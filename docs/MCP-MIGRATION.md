# MCP Migration Guide — v2.1 → v3.0 → v3.0.1

> **TL;DR (v3.0.1, 2026-04-23)** — Promoted `chrome-devtools-mcp` from optional to default. claude-forge now ships with **4 MCP servers** (playwright · context7 · jina-reader · chrome-devtools). Rationale: Lighthouse/Core-Web-Vitals diagnostics are a different class of browser work than general automation, and the two complement each other without overlap.
>
> **TL;DR (v3.0)** — claude-forge v3.0 shipped with **3 MCP servers** instead of v2.1's 6. The 4 removed servers have first-class replacements already built into Claude Code 2026 or the standard CLI toolbox. This guide explains each replacement.

## Why the Cut

v2.1 bundled `memory`, `exa`, `github`, and `fetch` as defaults. Four forces made this redundant in v3.0:

1. **Auto Memory landed in Claude Code (2026)** — the harness now persists user profile, feedback, and project facts under `~/.claude/projects/.../memory/` automatically. An MCP memory server became duplicate infrastructure for most users.
2. **WebSearch is first-class** — Claude Code ships a native `WebSearch` tool that covers >90% of what Exa did for general research.
3. **`gh` CLI is universal** — GitHub Actions, issues, PRs, releases, gists, and repo management all work via `gh` through the `Bash` tool. The MCP wrapper added no capabilities, only surface area.
4. **jina-reader + fallback** — a single URL-to-markdown server covers fetch duties; if blocked, Claude Code can still hit the URL directly.

Result: fewer dependencies for new users, faster install, lower token overhead on `ToolSearch`.

## The 4 Default Servers (v3.0.1)

| Server | Type | Replaces | Primary Use |
|--------|------|----------|-------------|
| **playwright** | stdio | (new in v3.0) | Browser automation — navigate/click/screenshot/trace |
| **context7** | stdio | (kept) | Up-to-date library docs (React, Next.js, Prisma, etc.) — use **before** writing library code |
| **jina-reader** | stdio | fetch | URL → markdown, token-efficient page content |
| **chrome-devtools** | stdio | (promoted in v3.0.1) | Lighthouse audits, Core Web Vitals (LCP/INP/CLS), memory snapshots, network inspection |

### Why `chrome-devtools` joins the default set (v3.0.1)

`playwright` covers general browser automation (click/fill/navigate), but quantitative diagnostics — Lighthouse scoring, LCP/INP/CLS measurement, V8 heap snapshots, CPU throttling — are Chrome DevTools Protocol territory. Users on performance-sensitive projects were importing `chrome-devtools` from `mcp-servers.optional.json` ~100% of the time, so keeping it optional added friction without upside. The two servers now coexist: `playwright` for "does this UI work?" and `chrome-devtools` for "how fast is it?"

Cost: one extra npx spin-up on first invocation (server is stdio, so no idle cost). If you never run Lighthouse/perf audits, the server simply never starts.

## Per-Server Replacement Recipes

### `memory` → Auto Memory + optional MCP

**What Auto Memory covers:** user facts, feedback corrections, project context, references to external systems. Stored at `~/.claude/projects/<project>/memory/MEMORY.md` with typed entries (`user`, `feedback`, `project`, `reference`).

**If you still need the MCP memory server** (team-shared knowledge graph, cross-project), add it from `mcp-servers.optional.json`:

```bash
# copy the "memory" entry from optional → main
# then reinstall
./install.sh --upgrade
```

### `exa` → WebSearch + optional MCP

**WebSearch** is available as a built-in tool — no setup, no token. For 90% of "find me recent articles on X" needs.

**Keep `exa` when:** you need Exa-specific features — semantic company/people search, domain filters, citation-grade sources. Then copy from `mcp-servers.optional.json`.

### `github` → `gh` CLI + optional MCP

`gh` is installable on every platform and integrates through `Bash`:

```bash
gh pr create --title "..." --body "..."
gh issue list --state open
gh api repos/OWNER/REPO/contents/path
gh release create v3.0.0 --notes-file CHANGELOG.md
```

**Keep `github` MCP when:** managed policies disable `Bash(gh:*)` for your org. Then enable it from `mcp-servers.optional.json` and scope permissions tightly.

### `fetch` → `jina-reader` + fallback

`jina-reader` converts any URL to clean markdown and handles most sites. If jina is rate-limited, Claude Code falls back to native HTTP via `WebFetch` (blocked by default in claude-forge — enable only as last resort).

**Keep `fetch` MCP when:** you need mcp-server-fetch's specific caching or proxy features. Copy from `mcp-servers.optional.json`.

## Adding Servers Back

Three steps:

```bash
# 1. View optional catalog
cat mcp-servers.optional.json | jq '.servers | keys'

# 2. Copy an entry
jq '.servers.memory' mcp-servers.optional.json > /tmp/memory.json
# Hand-merge into mcp-servers.json under "servers"

# 3. Reinstall
./install.sh --upgrade
```

`install.sh --upgrade` detects mcp-servers.json changes and reregisters the servers.

## Settings.json Implications

v3.0 ships `settings.json` with allowlist entries for the 3 default MCP namespaces only:

```json
"allow": [
  "mcp__playwright__*",
  "mcp__context7__*",
  "mcp__jina-reader__*"
]
```

When adding a server back, also add its `mcp__<server>__*` to `permissions.allow`, and consider adding it to `enabledMcpjsonServers` for explicit activation.

## FAQ

**Q: I have v2.1 workflows that call `mcp__memory__*`. Will they break?**
A: Yes — the tool becomes unavailable. Either migrate to Auto Memory or restore the server from the optional file.

**Q: Can I run more than 3 servers?**
A: Yes. The 3-server default is a minimum, not a maximum. There is no practical cap; each server costs a few MB RAM + startup time.

**Q: Does this affect plugin distribution?**
A: No. `plugin.json` does not list MCP servers — they're project-scoped in `mcp-servers.json`.

## References

- Claude Code MCP docs: https://code.claude.com/docs/en/mcp
- Auto Memory: https://docs.anthropic.com/en/docs/claude-code/memory
- Playwright MCP: https://github.com/microsoft/playwright-mcp
- Context7: https://upstash.com/blog/context7-mcp
- Jina Reader: https://github.com/jina-ai/jina-mcp-tools
