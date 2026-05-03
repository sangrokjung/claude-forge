# Meta-marketplace submission packets

> **Status (2026-05-03):** Field-by-field paste-ready values for 3 community meta-marketplaces.
> Form clicks must be done by the maintainer (sangrokjung) — these are browser-only.

These supplement the official Anthropic directory submission documented in
[`MARKETPLACE-SUBMISSION.md`](../MARKETPLACE-SUBMISSION.md). The official
directory has a long review cycle; these meta-marketplaces typically index
within hours-to-days.

---

## 1. claudemarketplaces.com

**Landing:** <https://claudemarketplaces.com/>
**Submission URL:** look for "Submit" / "Add your marketplace" button on the landing page; if not visible, the site may auto-index from public `marketplace.json` files (no action required) or accept GitHub PRs to a backing repo. **Verify before submitting.**

| Field | Value |
|---|---|
| Marketplace name | `claude-forge` |
| Type | Single-plugin marketplace |
| GitHub URL | `https://github.com/sangrokjung/claude-forge` |
| `marketplace.json` path | `.claude-plugin/marketplace.json` |
| Install command | `/plugin marketplace add sangrokjung/claude-forge` |
| Category | development |
| Tags | agents, skills, hooks, tdd, code-review, security, automation, mcp-minimal, mcp-chrome-devtools, lighthouse, performance |
| Short description (≤140 chars) | oh-my-zsh for Claude Code — 11 agents · 33 commands · 24 skills · 15 hooks · 9 rules · 4 MCP servers in one install |
| License | MIT |
| Maintainer | Sangrok Jung (@sangrokjung) |

---

## 2. buildwithclaude.com

**Landing:** <https://buildwithclaude.com/>
**Backing repo:** [`davepoon/buildwithclaude`](https://github.com/davepoon/buildwithclaude) (2,859★)
**Submission URL:** check the landing page for a submit form; **most likely a PR to the davepoon/buildwithclaude repo.** Inspect that repo's CONTRIBUTING.md or README first.

| Field | Value |
|---|---|
| Plugin name | `claude-forge` |
| Author | Sangrok Jung (@sangrokjung) |
| GitHub URL | `https://github.com/sangrokjung/claude-forge` |
| Install instructions (verbatim) | Inside Claude Code: `/plugin marketplace add sangrokjung/claude-forge` then `/plugin install claude-forge`. For the full distribution (agents/hooks/rules/MCP), use `curl -fsSL https://raw.githubusercontent.com/sangrokjung/claude-forge/main/install.sh \| bash`. |
| Description (long form) | claude-forge is an "oh-my-zsh for Claude Code" — a cohesive, production-grade distribution of 11 specialized agents, 33 slash commands, 24 skills, 15 automation hooks (covering 21 lifecycle events), 9 rule files, and a minimal 4-server MCP set (playwright, context7, jina-reader, chrome-devtools@0.23.0). One install, full set. |
| Category | Development tools / Plugin distribution |
| License | MIT |
| Tags / keywords | claude-code, agents, skills, hooks, tdd, code-review, security, automation, mcp |

> **If buildwithclaude requires a PR:** follow the same protocol as Phase B awesome-list PRs (fork → branch `add-claude-forge` → edit → PR). The draft and submission command will then be added to `docs/distribution/awesome-prs/buildwithclaude.md`.

---

## 3. aitmpl.com/plugins

**Landing:** <https://www.aitmpl.com/plugins/>
**Submission URL:** look for "Submit" / "Add your plugin" button or contact form on the page.

(Same field set as claudemarketplaces.com.)

| Field | Value |
|---|---|
| Plugin name | `claude-forge` |
| GitHub URL | `https://github.com/sangrokjung/claude-forge` |
| Install command | `/plugin marketplace add sangrokjung/claude-forge` |
| Category | development |
| Short description (≤140 chars) | oh-my-zsh for Claude Code — 11 agents · 33 commands · 24 skills · 15 hooks · 9 rules · 4 MCP servers in one install |
| License | MIT |
| Maintainer | Sangrok Jung (@sangrokjung) |
| Contact | open an issue on the GitHub repo |

---

## Submission checklist (maintainer fills as forms are submitted)

- [ ] **claudemarketplaces.com submitted** — date: `____`, confirmation/PR #: `____`
- [ ] **buildwithclaude.com submitted** — date: `____`, PR # (if applicable): `____`
- [ ] **aitmpl.com/plugins submitted** — date: `____`

---

## Verification (after each submission)

| Site | Verification step |
|---|---|
| claudemarketplaces.com | Search for `claude-forge` on the directory page; expect a hit within 24-48h of confirmation. |
| buildwithclaude.com | Same — search the plugins index. If PR-based, watch the PR for merge. |
| aitmpl.com/plugins | Same — search the plugins index. |

If a site does not show the entry within 7 days of confirmation, open a follow-up issue on the maintaining repo (or contact via the form on the landing page).
