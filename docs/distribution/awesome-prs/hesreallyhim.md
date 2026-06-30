# PR draft: Add claude-forge to hesreallyhim/awesome-claude-code

## Target metadata
- Repo: hesreallyhim/awesome-claude-code
- Star count at draft time: 42,286
- Default branch: main
- Category to insert into: **TBD by maintainer** — see "Special note" below
- Insertion position: **N/A at this time** — the README does not currently have a structured Table of Contents
- PR template requirements: None (no `CONTRIBUTING.md`, no `.github/PULL_REQUEST_TEMPLATE.md`)

## Special note (CRITICAL — read before submitting)

As of 2026-05-03, `hesreallyhim/awesome-claude-code/README.md` is in a transitional state. The maintainer's `[!NOTE]` block states:

> The old ways have come and gone. It's time to embrace the next phase. The previous Table of Contents was no longer fit for purpose, so a new organizational system is being prepared.

The README body literally reads:
```
# Table of Contents

I. TODO

hm.
...
Claude: Just hit me up on Telegram, I'll sort it out.
Him: I don't have Telegram...
Claude: ... This does not bode well.
```

**Implication:** there is no standing category list to slot into. Two reasonable strategies:

1. **Watch-and-wait** — Hold this PR until the maintainer publishes the new TOC structure, then submit into the most appropriate category. Lowest risk of rejection-for-style.
2. **Submit anyway as discussion** — Open the PR with the entry below, explicitly saying "happy to relocate once new TOC is published", to get on the maintainer's radar.

**Recommendation:** Option 1. The 42K-star list is likely to land a major refresh; submitting before the structure exists invites churn.

## Entry to add (verbatim, ready for whatever category lands)

The list emphasizes "high quality skills, agents, hooks, status lines, orchestrators, developer tooling". An entry covering all of those at once should likely land under **Distributions** / **Frameworks** / **Plugins** / **Orchestrators** depending on the new taxonomy. Use this single-line bullet:

```markdown
- [Claude Forge](https://github.com/sangrokjung/claude-forge) — "oh-my-zsh for Claude Code": one install for 11 agents, 34 commands, 25 skills, 15 hooks (covering 21 lifecycle events) + 9 opt-in examples, 9 rules, statusLine, and a minimal 4-server MCP set (playwright · context7 · jina-reader · chrome-devtools@0.23.0). Ships TDD workflow, security review, code review, architecture analysis, build error resolution, and Chrome DevTools Lighthouse / Core Web Vitals audits. MIT.
```

## PR title
Add Claude Forge — production-grade Claude Code distribution (11 agents · 34 commands · 25 skills · 15 hooks)

## PR body

```markdown
Hi! Adding [Claude Forge](https://github.com/sangrokjung/claude-forge) to the list.

Claude Forge is an opinionated, production-grade Claude Code distribution that bundles agents, commands, skills, hooks, rules, and a minimal MCP set in **one install** (one-line `curl` or `/plugin marketplace add`). Inspired by the role oh-my-zsh plays for zsh.

**Why it fits this list:** it covers _all_ of the categories you call out in the README intro — skills, agents, hooks, status lines, orchestrators, developer tooling — in one cohesive distribution rather than a single-purpose contribution.

**At a glance:**
- 11 specialized subagents (planner, tdd-guide, code-reviewer, security-reviewer, architect, database-reviewer, build-error-resolver, doc-updater, refactor-cleaner, e2e-runner, verify-agent)
- 34 slash commands
- 25 production-grade skills
- 15 hooks (covering 21 lifecycle events) + 9 opt-in examples
- 9 rules, statusLine, 4 MCP servers
- License: MIT
- Active maintenance: weekly releases
- Submitted to `anthropics/claude-plugins-official` (in review)

I held off on picking a specific category because the README currently shows the TOC is being rebuilt. Happy to (a) wait for the new structure and resubmit, or (b) drop this entry into whatever category you suggest — your call.

— @sangrokjung
```

## Submission command (for maintainer to run)

```bash
# Step 1 — fork (browser or CLI)
gh repo fork hesreallyhim/awesome-claude-code --clone=false --remote=false

# Step 2 — clone the fork, branch
git clone https://github.com/sangrokjung/awesome-claude-code.git /tmp/cf-pr-hesreallyhim
cd /tmp/cf-pr-hesreallyhim
git checkout -b add-claude-forge

# Step 3 — DO NOT edit README.md yet (TOC is "TODO" — see Special note above).
# Recommended path: open the PR as a discussion-only entry with the body above and
# wait for the maintainer to confirm where it should land before adding the line.

# Step 4 — push the empty branch (just so the PR has a head)
git commit --allow-empty -m "Discussion: where to add Claude Forge once new TOC ships"
git push -u origin add-claude-forge

# Step 5 — open the PR
gh pr create \
  --repo hesreallyhim/awesome-claude-code \
  --base main \
  --head sangrokjung:add-claude-forge \
  --title "Add Claude Forge — production-grade Claude Code distribution (11 agents · 34 commands · 25 skills · 15 hooks)" \
  --body-file /Users/sangrok/claude-forge/docs/distribution/awesome-prs/hesreallyhim.md
```

(If the maintainer prefers immediate insertion, append the entry line to whatever section they suggest, commit, and push — no `--force` needed.)

## PR URL
(empty — fill after maintainer submits)

## Status
DRAFT — awaiting maintainer review and submission. **Recommended action: hold until upstream TOC stabilizes.**
