# Marketplace Submission Packet

> Target: [`github.com/anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) `external_plugins/` (community directory).
>
> Submission form: <https://clau.de/plugin-directory-submission>
>
> **Status (2026-04-24):** Ready for submission. All items in the reviewer-facing
> checklist (§6) are verified against `main` at commit 51bef80. This document is the
> final submission packet — values in §7 are ready to paste.

## 1. Plugin Metadata (paste into the submission form)

| Field | Value |
|-------|-------|
| Plugin name | `claude-forge` |
| Maintainer | Sangrok Jung |
| Public repository | <https://github.com/sangrokjung/claude-forge> |
| Homepage | <https://github.com/sangrokjung/claude-forge> |
| License | MIT |
| Current version | `3.0.1` |
| Manifest file | `.claude-plugin/plugin.json` |
| Marketplace manifest | `.claude-plugin/marketplace.json` |
| Category | development |
| Tags | agents, skills, hooks, tdd, code-review, security, automation, mcp-minimal, mcp-chrome-devtools, lighthouse, performance |

## 2. One-paragraph pitch

claude-forge is an "oh-my-zsh for Claude Code" — a cohesive distribution of 11 specialized
agents, 33 slash commands, 24 skills, 15 automation hooks (plus 9 opt-in examples covering
21 lifecycle events), 9 rule files, and a minimal 4-server MCP set (playwright, context7,
jina-reader, chrome-devtools pinned at `@0.23.0`). It targets individual developers and
small teams who want a production-grade, security-reviewed baseline without hand-assembling
the 2026 Anthropic Claude Code standard (Skills/Commands split, 21 hook events, subagent
frontmatter v2). One install gives the complete set, and `install.sh --upgrade` migrates
v2.1 users in place with backup + diff preview.

## 3. What users get (inventory)

- **11 agents** with frontmatter v2 (planner, tdd-guide, code-reviewer, security-reviewer,
  architect, database-reviewer, build-error-resolver, doc-updater, refactor-cleaner,
  e2e-runner, verify-agent)
- **33 commands** (`/auto-ship`, `/plan`, `/review`, `/e2e`, `/worktree-start`, ...)
- **24 skills** under `skills/<name>/SKILL.md`
- **15 hooks + 9 opt-in examples** covering 21 of the 27 official hook events
- **9 rules** (Golden Principles, interaction, coding-style, verification, security,
  testing, git-workflow, date-calculation, agents-v2)
- **4 MCP servers** (default) + 7 optional in `mcp-servers.optional.json`
- CC CHIPS status bar submodule (optional)
- `install.sh` / `install.ps1` for macOS/Linux/Windows

## 4. Installation paths

### Plugin install (available today, partial coverage)

Two-step official syntax — register the marketplace first, then install the plugin:

```
/plugin marketplace add sangrokjung/claude-forge
/plugin install claude-forge
```

This path delivers Commands + (most) Skills. Agents / Hooks / Rules / MCP / statusLine
currently require the classic `install.sh` — see
[`docs/PLUGIN-VS-INSTALL-SH.md`](./PLUGIN-VS-INSTALL-SH.md) for the full matrix. This is
a Claude Code loader limitation, not a repository limitation.

### Via `claude-plugins-official` (after approval)

Once accepted into the community directory:

```
/plugin install claude-forge@claude-plugins-official
```

### Legacy `install.sh` (full coverage, recommended for production use)

Symlink-based install into `~/.claude/`. Still the only path that wires up agents, hooks,
rules, the 4 MCP servers, statusLine (CC CHIPS submodule), and `settings.json` env
blocks. This is what most users should actually run.

## 5. Security & quality review summary

claude-forge underwent a 4-way independent skeptical review on 2026-04-23 (super-research /
security-reviewer / architect / codex-reviewer). All verdicts were conditional; blocking
issues were closed inside PR #38 and this submission packet is written against the
post-fix state.

### Verified (Tier 0 public docs, 2026-04-23)
- No plaintext credentials in the repo (`rg -n "sk-|api_key|TOKEN" --glob '!**/node_modules/**'` → 0 hits at time of submission)
- All MCP servers declared in `mcp-servers.json` resolve to versioned/audited sources:
  - `@playwright/mcp@latest` (Microsoft)
  - `@upstash/context7-mcp@latest` (Upstash)
  - `jina-mcp-tools` (Jina AI)
  - `chrome-devtools-mcp@0.23.0` (Google Chrome DevTools org, Apache-2.0, pinned)
- `permissions.deny` in `settings.json` blocks the canonical destructive patterns
  (rm -rf, sudo, git force-push to main, curl|sh, eval, exec via node/python/perl, etc.)
- Hook script inventory: every hook declared in `settings.json` resolves to a file
  that exists under `hooks/` (verified by `validate.yml` installer job)
- Hook `timeout` values use the correct SemVer-unit-seconds (not milliseconds) — verified
  against <https://code.claude.com/docs/en/hooks> on 2026-04-23

### Known limitations (tracked publicly)
- All 11 npm-loaded MCP packages are now SemVer-pinned (PRs #38, #41, #42). `uvx`-based
  fetch/time in `mcp-servers.optional.json` use the upstream unversioned entrypoint —
  tracked as a separate follow-up (different ecosystem).
- Some `UNVERIFIED` settings fields (`tui`, `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`,
  `env.ENABLE_TOOL_SEARCH`) are not present in the public settings reference but work at
  runtime. Tracked in [`docs/SETTINGS-COMPATIBILITY.md`](./SETTINGS-COMPATIBILITY.md).
- The Chrome DevTools plugin (maintained by Google) and the default MCP server entry in
  `mcp-servers.json` can both be enabled simultaneously. This is idempotent at the stdio
  layer but is documented as a follow-up (plugin-vs-manifest collision detection).
- The Claude Code plugin loader currently covers only Commands + (most) Skills for this
  repo. Agents / Hooks / Rules / MCP / statusLine / `settings.json` env are intentionally
  wired through `./install.sh`. Fully documented in
  [`docs/PLUGIN-VS-INSTALL-SH.md`](./PLUGIN-VS-INSTALL-SH.md) so reviewers and users
  know exactly what the "plugin" entrypoint delivers vs the "install.sh" entrypoint.

### CI coverage (`.github/workflows/validate.yml`, 5 jobs)
1. `json` — JSON syntax + MCP v3 minimum + settings.json v3 fields
2. `marketplace-schema` — plugin.json/marketplace.json required fields, version drift,
   SemVer format
3. `frontmatter` — agents/skills frontmatter schema
4. `installer` — install.sh bash syntax + `--dry-run` smoke
5. `security` — secret scan + permissive patterns audit

## 6. Reviewer-facing checklist

Every box below has been verified against `main` at commit `51bef80` (2026-04-24).

- [x] README `Quick Start` shows the two-step plugin install (`/plugin marketplace add
      sangrokjung/claude-forge` then `/plugin install claude-forge`) and clearly discloses
      that Agents / Hooks / Rules / MCP / statusLine currently require `./install.sh`.
      Verified: `grep -c "/plugin marketplace add sangrokjung/claude-forge" README.md` = 4.
- [x] `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` agree on the
      same `version` (CI job `marketplace-schema` enforces this). Verified: all three
      version fields are `3.0.1`.
- [x] `version` follows SemVer `X.Y.Z`. Verified: `3.0.1` matches regex `^[0-9]+\.[0-9]+\.[0-9]+$`.
- [x] `license` is MIT and a `LICENSE` file exists at the repo root. Verified: `ls LICENSE` succeeds.
- [x] `homepage` and `repository` URLs resolve and are public. Verified: `HTTP/2 200`
      on `https://github.com/sangrokjung/claude-forge`.
- [x] No existing entry named `claude-forge` in
      `anthropics/claude-plugins-official/external_plugins/` at the time of submission.
      Verified: `HTTP/2 404` on the external_plugins/claude-forge path.
- [x] MCP servers and their licenses are listed in `docs/MCP-MIGRATION.md` with sources.
- [x] A release tag (`v3.0.1`) and a corresponding GitHub Release exist. Verified via
      `gh release view v3.0.1`.
- [x] Latest 4-way skeptical review results are linked or summarized (see section 5).

## 7. Submission body (template — copy/paste into the form)

```
Plugin name: claude-forge
Version: 3.0.1
Repository: https://github.com/sangrokjung/claude-forge
Maintainer: Sangrok Jung (@sangrokjung)
License: MIT
Category: development

Installable today via (two-step, partial coverage):
  /plugin marketplace add sangrokjung/claude-forge
  /plugin install claude-forge
(Agents / Hooks / Rules / MCP / statusLine still require ./install.sh —
 see docs/PLUGIN-VS-INSTALL-SH.md for the complete matrix.)

Short description:
  oh-my-zsh for Claude Code — 11 agents, 33 commands, 24 skills, 15 hooks +
  9 opt-in examples (21 events), 9 rules, 4 MCP in one install.

Security & quality:
  - 4-way independent skeptical review (super-research, security, architect, codex)
    completed 2026-04-23; all blocking issues closed in PR #38.
  - CI validate.yml enforces JSON syntax, plugin manifest schema, version drift,
    SemVer format, frontmatter schema, installer smoke, and secret scan.
  - All 11 npm-loaded MCP packages are SemVer-pinned (no `@latest`):
    playwright@0.0.70, context7@2.1.8, jina-mcp-tools@1.2.3,
    chrome-devtools@0.23.0, server-memory@2026.1.26, server-github@2025.4.8,
    sequential-thinking@2025.12.18, mcp-server-supabase@0.7.0.
  - plugin.json follows the official Claude Code plugin manifest spec exactly
    (no custom fields — verified against reference plugins superpowers/claude-hud).

Compatibility notes:
  - Requires Claude Code >= 2.1.110 (minClaudeCodeVersion declared in plugin.json).
  - Version 3.0.1 is a compatible patch release on top of 3.0 (Anthropic 2026
    standard alignment). v2.1 users can migrate via `./install.sh --upgrade`.

Why this belongs in the community directory:
  Provides a vetted, actively maintained baseline for developers who want to
  operate Claude Code at production quality without hand-assembling agents,
  commands, skills, and hooks. It fills the same role oh-my-zsh fills for zsh.

Additional context:
  - CONTRIBUTING.md has an explicit "Publishing to the Plugin Directory" section
    and a pre-release QA checklist, so future releases keep the directory entry
    in sync automatically.
  - Full submission packet: docs/MARKETPLACE-SUBMISSION.md
```

## 8. Post-approval tasks

- [ ] Update README to mention the official-directory install path
      (`claude-forge@claude-plugins-official`) alongside the existing self-hosted
      marketplace path.
- [ ] Announce via GitHub Discussions / release notes.
- [ ] Add a CI job that opens an issue whenever a new minor version lands in this repo
      but hasn't been proposed as a PR to `anthropics/claude-plugins-official`.
- [ ] Periodically (monthly) re-run the 4-way skeptical review and attach the diff to
      `CHANGELOG.md`.

## 9. Contact

- Primary maintainer: [@sangrokjung](https://github.com/sangrokjung)
- Security reports: open a **private** advisory on the GitHub repository.
