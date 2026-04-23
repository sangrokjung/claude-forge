# ADR-001: MCP Default Server Set (v2.1 → v3.0 → v3.0.1)

**Status:** Accepted
**Date:** 2026-04-23
**Deciders:** claude-forge maintainers
**Context PR:** [#38](https://github.com/sangrokjung/claude-forge/pull/38) (chore/mcp-hook-cleanup, follow-up to [#31](https://github.com/sangrokjung/claude-forge/pull/31))

---

## Context and Problem Statement

claude-forge v2.1 shipped with 6 MCP servers as the default set: `playwright`, `context7`, `jina-reader`, `memory`, `exa`, `fetch`, `github`. Two forces made this costly:

1. **Redundancy with Claude Code 2026 built-ins.** Auto Memory (`~/.claude/projects/<project>/memory/`, v2.1.59+) persists user/feedback/project facts automatically. `WebSearch` is a native tool. `gh` CLI covers GitHub via Bash. Real-world telemetry across our harness shows `memory` at 0 calls and `fetch` at near-zero use — the MCPs were paying installation cost (npx spin-up, ToolSearch overhead) for no unique value.

2. **Lighthouse / performance auditing is a separate domain from general automation.** `playwright` handles navigate/click/screenshot but cannot produce Core Web Vitals, Lighthouse scores, V8 heap snapshots, or CPU throttling profiles. `chrome-devtools-mcp` (Google ChromeDevTools org, Apache-2.0) does exactly this. Keeping it optional meant ~100% of perf-sensitive projects copy-pasted from `mcp-servers.optional.json` — friction without upside.

The decision had to balance: minimal install surface for new users vs. reproducibility of the harness people actually use, vs. risk from supply-chain drift on unpinned deps.

## Decision Drivers

- **Measured use.** Decide from telemetry, not intuition.
- **Avoid duplicating native Claude Code features.** Auto Memory, WebSearch, `gh` CLI make their MCP counterparts redundant for the 90% case.
- **Supply-chain discipline.** Every default server must be version-pinned.
- **Reversibility.** Anything removed must be one copy-paste + `./install.sh --upgrade` away from restoration.
- **Public-repo hygiene.** No secrets, no unpinned `@latest` in the set that 3rd-party forks inherit.

## Considered Options

### Option A — Keep all 6 (status quo v2.1)
- ✗ Pays spin-up cost for 2–3 unused servers per session.
- ✗ Violates "minimal surface for new users" principle.
- ✗ ToolSearch overhead proportional to registered server count.

### Option B — Reduce to 3 (playwright / context7 / jina-reader) *(v3.0 shipped)*
- ✓ Minimal cognitive load for new installs.
- ✗ Does not solve Lighthouse/perf gap; users re-add `chrome-devtools-mcp` manually.
- ✗ `memory` and `fetch` breakage handled via MIGRATION.md but no formal decision record.

### Option C — Reduce to 4 (add chrome-devtools, keep v3.0 trio) *(chosen, v3.0.1)*
- ✓ Covers the two most-requested browser workloads (automation + perf auditing) with clearly different responsibilities.
- ✓ Version-pinned (`chrome-devtools-mcp@0.23.0`) to cap supply-chain blast radius.
- ✓ `memory`, `fetch`, `exa`, `github` kept available via `mcp-servers.optional.json` with documented restoration path.
- ✗ One extra stdio server = ~500 ms first-invoke npx warm-up when Lighthouse is actually run.
- ✗ Two browser-adjacent servers increases the chance of a user enabling both plus the chrome-devtools plugin simultaneously (triple-registration risk — see Consequences).

### Option D — Add all promoted servers (4 core + time + sequential-thinking)
- ✗ `time`/`sequential-thinking` have no measured regular use in our telemetry.
- ✗ Violates "default only what the average user will use weekly" guideline.

## Decision Outcome

**Chosen: Option C** — 4-server default set (`playwright`, `context7`, `jina-reader`, `chrome-devtools`), with `chrome-devtools` **pinned to `@0.23.0`**.

Removed from default (still available in `mcp-servers.optional.json`):
- `memory` → Claude Code Auto Memory (v2.1.59+)
- `fetch` → `jina-reader` + `WebSearch` native
- `exa` → `WebSearch` native
- `github` → `gh` CLI via Bash

Pinning policy: all default servers **should** carry explicit version pins. Current compliance:
- ✓ `chrome-devtools-mcp@0.23.0` (pinned this ADR)
- ✗ `@playwright/mcp@latest` (inherited from v3.0; pinning deferred to separate follow-up)
- ✗ `@upstash/context7-mcp@latest` (inherited; pinning deferred)
- ✓ `jina-mcp-tools` (no tag; resolves by npm default — acceptable since package has no prior semver chaos)

Follow-up task: pin `playwright` and `context7` in a separate ADR once upstream release cadence is confirmed.

## Consequences

**Positive**
- New-user install surface reduced 6 → 4 (vs. v2.1) while covering the two dominant browser workloads.
- Auto Memory / WebSearch / `gh` CLI substitutions formalize "use built-ins first" as policy, not coincidence.
- `chrome-devtools-mcp` supply-chain attack surface bounded by `@0.23.0` pin.

**Negative**
- Breaking change for existing users who wrote `mcp__memory__*` / `mcp__fetch__*` calls. Mitigation: `mcp-servers.optional.json` + MIGRATION.md restoration recipes; affected agents (`doc-updater`, `refactor-cleaner`, `database-reviewer`) rewritten to prefer Auto Memory / `git log` / migration files.
- Users who have the Chrome DevTools plugin enabled AND reinstall claude-forge with v3.0.1 will have `chrome-devtools` registered twice (plugin + mcp-servers.json). stdio MCP servers tolerate duplicate registration (each session spawns its own process) but double spawn = double cost. Mitigation: install.sh should emit a warning on duplicate detection (tracked as follow-up).
- Measurement metric (`total_wall = max(end_ms) - min(start_ms)`) added via `hooks/_lib/timing.sh` conflates "sequential spawn then parallel exec" with "true parallel exec" when harness dispatches hooks with 10–50 ms stagger. Current reading: directional only, not definitive proof of `async: true` behavior.

## Compliance / Follow-up

- [ ] Pin `@playwright/mcp` and `@upstash/context7-mcp` versions (separate ADR).
- [ ] install.sh: warn on `chrome-devtools` plugin-vs-mcp-servers.json duplicate.
- [ ] hooks/_lib/timing.sh: expose dispatch time from harness if possible (`HOOK_DISPATCH_MS` env) to distinguish sequential spawn from serial exec.
- [ ] Quarterly review of MCP call frequency; demote any server below threshold back to optional.

## References

- [Claude Code MCP docs](https://docs.anthropic.com/en/docs/claude-code/mcp) (Tier 0, 2026-04-23)
- [Claude Code Auto Memory](https://code.claude.com/docs/en/memory) (Tier 0, 2026-04-23, v2.1.59+)
- [MCP Security Best Practices](https://modelcontextprotocol.io/docs/tutorials/security/security_best_practices) (Tier 0)
- [ChromeDevTools/chrome-devtools-mcp v0.23.0](https://github.com/ChromeDevTools/chrome-devtools-mcp/releases/tag/v0.23.0) (Tier 0, 2026-04-22)
- [claude-forge MIGRATION.md §MCP default cut](https://github.com/sangrokjung/claude-forge/blob/feat/v3.0/MIGRATION.md)
- Review dossier: `~/.claude/plans/scalable-waddling-sphinx.md` (`## 독립 회의적 리뷰 결과` section)
