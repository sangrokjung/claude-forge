# PR draft: Add claude-forge to ComposioHQ/awesome-claude-plugins

## Target metadata
- Repo: ComposioHQ/awesome-claude-plugins
- Star count at draft time: 1,599 (≈ 1.6K)
- Default branch: **`master`** (NOT `main` — the only target in this batch using master)
- Category to insert into: **`### Developer Productivity`** (under `## Plugins`) — best fit because claude-forge is a developer-productivity bundle (multi-agent + hooks + skills + rules). Alternative: `### Backend & Architecture` if maintainer prefers single-domain.
- Insertion position: alphabetical, after `CCHub` and before `developer-growth-analysis`. The list mixes external repos (`https://github.com/...`) and internal plugin folders (`./plugin-name`).
- PR template requirements: No `CONTRIBUTING.md`. Format inferred from existing entries.

## Format observed in this list

This list accepts **both** internal plugin folders and external repo links — see the `### Developer Productivity` section for examples of both:

```markdown
- [CCHub](https://github.com/Moresl/cchub) - Description...               ← external link
- [skill-bus](./skill-bus) - The skill for connecting skills...           ← internal folder
- [context-mode](https://github.com/mksglu/claude-context-mode) - ...    ← external link
```

This makes claude-forge submission easier than ccplugins (no requirement to mirror plugin folder into the repo). External link is acceptable.

## Strategy

**Recommended:** Strategy B (external link). The list explicitly accepts external `https://github.com/...` entries in the same section, so we don't need to mirror the plugin folder inside ComposioHQ's repo. Less maintenance burden, less merge conflict surface.

If the maintainer pushes back, fall back to Strategy A (mirror plugin folder per ComposioHQ's `Plugin Structure` template documented in their README, lines 187-200).

## Entry to add (verbatim, in the project's existing format)

Insert into `### Developer Productivity`, alphabetically after `CCHub`:

```markdown
- [claude-forge](https://github.com/sangrokjung/claude-forge) - A complete plugin extending Claude Code with 11 custom agents, 34 commands, 25 skills, 15 hooks (covering 21 lifecycle events), 9 rules, and 4 MCP servers (playwright, context7, jina-reader, chrome-devtools@0.23.0). Plugin manifest follows the official Claude Code plugin spec exactly. Install via `/plugin marketplace add sangrokjung/claude-forge` then `/plugin install claude-forge`. MIT.
```

## PR title
Add claude-forge to Developer Productivity (11 agents · 34 commands · 25 skills · 15 hooks · 4 MCP)

## PR body

```markdown
Hi ComposioHQ team! Adding [claude-forge](https://github.com/sangrokjung/claude-forge) under **Developer Productivity**.

**Why Developer Productivity:** It's a multi-component plugin distribution — agents, commands, skills, hooks, rules, MCP — that fits the same shape as `CCHub`, `skill-bus`, `backlog`, etc. in your existing Developer Productivity section. Happy to relocate to **Backend & Architecture** or any category you prefer.

**Plugin spec compliance** (your README's `Plugin Structure` template, lines 187-200):
- ✅ `.claude-plugin/plugin.json` — [manifest](https://github.com/sangrokjung/claude-forge/blob/main/.claude-plugin/plugin.json)
- ✅ `.claude-plugin/marketplace.json` — [marketplace metadata](https://github.com/sangrokjung/claude-forge/blob/main/.claude-plugin/marketplace.json)
- ✅ `skills/` — 24 SKILL.md files
- ✅ `commands/` — 34 slash commands
- ✅ `agents/` — 11 agent definitions
- ✅ `hooks/` — 15 lifecycle hooks (21 events covered)

**Install:**
```
/plugin marketplace add sangrokjung/claude-forge
/plugin install claude-forge
```

**Vetting:**
- Submitted to [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) (in review)
- 4-way independent skeptical review completed 2026-04-23 (super-research / security / architect / codex)
- Active maintenance: weekly releases
- License: MIT

Note: I'm submitting as an external link (matching the `CCHub` / `claude-context-mode` style in this section) rather than mirroring the plugin folder. Happy to switch to a folder mirror per your `Plugin Structure` template if you'd prefer the in-repo convention.

— @sangrokjung
```

## Submission command (for maintainer to run)

```bash
# Step 1 — fork
gh repo fork ComposioHQ/awesome-claude-plugins --clone=false --remote=false

# Step 2 — clone, branch (NOTE: default branch is master, not main)
git clone https://github.com/sangrokjung/awesome-claude-plugins.git /tmp/cf-pr-composiohq
cd /tmp/cf-pr-composiohq
git checkout -b add-claude-forge

# Step 3 — Edit README.md
# Find "### Developer Productivity" (~line 146)
# Insert the entry after "- [CCHub](https://github.com/Moresl/cchub) - ..."

# Step 4 — verify
grep -c 'sangrokjung/claude-forge' README.md  # expect: 1

# Step 5 — commit, push, open PR
git add README.md
git commit -m "Add claude-forge to Developer Productivity"
git push -u origin add-claude-forge
gh pr create \
  --repo ComposioHQ/awesome-claude-plugins \
  --base master \
  --head sangrokjung:add-claude-forge \
  --title "Add claude-forge to Developer Productivity (11 agents · 34 commands · 25 skills · 15 hooks · 4 MCP)" \
  --body-file /Users/sangrok/claude-forge/docs/distribution/awesome-prs/composiohq.md
```

## PR URL
https://github.com/ComposioHQ/awesome-claude-plugins/pull/210

## Status
DRAFT — awaiting maintainer review and submission. **External link strategy chosen** (matches existing convention in `Developer Productivity` section).
