# Marketplace Submission Packet

> Target: [`github.com/anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official) `external_plugins/` (community directory).
>
> Submission form: <https://clau.de/plugin-directory-submission>
>
> **Status (2026-04-23):** Not yet submitted. This document is a dry-run packet — filling it in once before submission guarantees that every field the reviewers ask for is already agreed on inside the repo.

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

### Direct (available today)

```
/plugin install sangrokjung/claude-forge
```

### Via this marketplace (after approval)

```
/plugin install claude-forge@claude-plugins-official
```

### Legacy `install.sh` (existing users)

Symlink-based install into `~/.claude/`. Retained for people who also want shell aliases
(`cc`, `ccr`), the CC CHIPS status bar submodule, or bootstrapped MCP credentials.

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
- `@playwright/mcp` and `@upstash/context7-mcp` are still pinned to `@latest`. Tracked as
  a follow-up in [`docs/adr/ADR-001-mcp-default-set.md`](./adr/ADR-001-mcp-default-set.md).
- Some `UNVERIFIED` settings fields (`tui`, `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`,
  `env.ENABLE_TOOL_SEARCH`) are not present in the public settings reference but work at
  runtime. Tracked in [`docs/SETTINGS-COMPATIBILITY.md`](./SETTINGS-COMPATIBILITY.md).
- The Chrome DevTools plugin (maintained by Google) and the default MCP server entry in
  `mcp-servers.json` can both be enabled simultaneously. This is idempotent at the stdio
  layer but is documented as a follow-up (plugin-vs-manifest collision detection).

### CI coverage (`.github/workflows/validate.yml`, 5 jobs)
1. `json` — JSON syntax + MCP v3 minimum + settings.json v3 fields
2. `marketplace-schema` — plugin.json/marketplace.json required fields, version drift,
   SemVer format
3. `frontmatter` — agents/skills frontmatter schema
4. `installer` — install.sh bash syntax + `--dry-run` smoke
5. `security` — secret scan + permissive patterns audit

## 6. Reviewer-facing checklist

Before opening the submission, every box below must be checked in the current
`main` (or the release tag being submitted).

- [ ] README `Quick Start` shows `/plugin install sangrokjung/claude-forge` as the primary
      installation path.
- [ ] `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` agree on the
      same `version` (CI job `marketplace-schema` enforces this).
- [ ] `version` follows SemVer `X.Y.Z`.
- [ ] `license` is MIT (or an OSI-approved compatible license) and a `LICENSE` file
      exists at the repo root.
- [ ] `homepage` and `repository` URLs resolve and are public.
- [ ] No existing entry named `claude-forge` in
      `anthropics/claude-plugins-official/external_plugins/` at the time of submission.
- [ ] MCP servers and their licenses are listed in `docs/MCP-MIGRATION.md` with sources.
- [ ] A release tag (`v3.0.1` or the version being submitted) and a corresponding
      GitHub Release exist.
- [ ] Latest 4-way skeptical review results are linked or summarized (see section 5).

## 7. Submission body (template — copy/paste into the form)

```
Plugin name: claude-forge
Version: 3.0.1
Repository: https://github.com/sangrokjung/claude-forge
Maintainer: Sangrok Jung (@sangrokjung)
License: MIT
Category: development

Installable today via:
  /plugin install sangrokjung/claude-forge

Short description:
  oh-my-zsh for Claude Code — 11 agents, 33 commands, 24 skills, 15 hooks +
  9 opt-in examples (21 events), 9 rules, 4 MCP in one install.

Security & quality:
  - 4-way independent skeptical review (super-research, security, architect, codex)
    completed 2026-04-23; all blocking issues closed in PR #38.
  - CI validate.yml enforces JSON syntax, plugin manifest schema, version drift,
    SemVer format, frontmatter schema, installer smoke, and secret scan.
  - All default MCP servers point to audited sources; chrome-devtools-mcp pinned
    to 0.23.0.

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

- [ ] Update README to mention both install paths (`sangrokjung/claude-forge` and
      `claude-forge@claude-plugins-official`).
- [ ] Announce via GitHub Discussions / release notes.
- [ ] Add a CI job that opens an issue whenever a new minor version lands in this repo
      but hasn't been proposed as a PR to `anthropics/claude-plugins-official`.
- [ ] Periodically (monthly) re-run the 4-way skeptical review and attach the diff to
      `CHANGELOG.md`.

## 9. Contact

- Primary maintainer: [@sangrokjung](https://github.com/sangrokjung)
- Security reports: open a **private** advisory on the GitHub repository.
