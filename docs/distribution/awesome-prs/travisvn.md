# PR draft: Add claude-forge to travisvn/awesome-claude-skills

## Target metadata
- Repo: travisvn/awesome-claude-skills
- Star count at draft time: 12,037 (≈ 12K)
- Default branch: main
- Category to insert into: **`### Collections & Libraries`** (under `## 🌟 Community Skills`) — claude-forge is a multi-skill bundle, not a single SKILL.md
- Insertion position: alphabetically between `obra/superpowers-lab` and the next entry. Since the existing entries are bullet-list with `- **[name](url)** - description` format and nested sub-bullets, follow that exact structure.
- PR template requirements: `CONTRIBUTING.md` is moderate-strict — see "PR template requirements" below

## PR template requirements (from CONTRIBUTING.md)

Quality standards (must satisfy ALL):
- ✅ **Related to Claude Skills** — claude-forge ships 25 production-grade skills, qualifies
- ✅ **Provides clear value** — "oh-my-zsh for Claude Code", multi-skill bundle
- ✅ **Non-promotional** — "No SaaS Wrappers", no paid funnel, all open-source MIT
- ✅ **Accurate, up-to-date** — v3.0.1 latest release, weekly updates
- ✅ **Standalone Value** — works on its own without paid services
- ✅ **Genuine Resource** — not a teaser, full source on GitHub

**Social proof (NEW requirement, 2026):** Submission must demonstrate adoption / community vetting. Mention:
- Submitted to `anthropics/claude-plugins-official` (in review)
- 4-way independent skeptical review completed 2026-04-23 (super-research / security / architect / codex)
- Active maintenance: weekly releases

Bullet format for `Collections & Libraries`:
```
- **[name](link)** - Description (1-2 sentences)
  - Optional sub-bullet 1
  - Optional sub-bullet 2
  - Installation: `<command>`
```

## Entry to add (verbatim, in the project's existing format)

Insert into `## 🌟 Community Skills` → `### Collections & Libraries`, after the `obra/superpowers-lab` block:

```markdown
- **[Claude Forge](https://github.com/sangrokjung/claude-forge)** — Production-grade Claude Code distribution including **25 skills** (auto-ship, frontend-design, security-review, ci-bi, blog-publish, daily-report, content-creator, generate-image, etc.) plus the agent harness needed to make them work end-to-end (11 agents, 34 commands, 15 hooks, 4 MCP servers, statusLine).
  - Skills follow the Anthropic 2026 Skills/Commands hybrid policy with documented boundary in [`docs/SKILLS-VS-COMMANDS.md`](https://github.com/sangrokjung/claude-forge/blob/main/docs/SKILLS-VS-COMMANDS.md)
  - Submitted to [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) (in review)
  - Inspired by oh-my-zsh's role for zsh
  - Installation: `/plugin marketplace add sangrokjung/claude-forge` (lightweight) or `curl -fsSL https://raw.githubusercontent.com/sangrokjung/claude-forge/main/install.sh | bash` (full)
  - License: MIT
```

## PR title
Add Claude Forge — 24-skill production-grade distribution (Collections & Libraries)

## PR body

```markdown
Hi Travis! Adding [Claude Forge](https://github.com/sangrokjung/claude-forge) to the **Collections & Libraries** section.

**What it is:** A production-grade Claude Code distribution that bundles 25 skills together with the supporting harness (11 agents, 34 commands, 15 hooks, 4 MCP servers, statusLine) so the skills work end-to-end. Inspired by oh-my-zsh's role for zsh.

**Why Collections & Libraries (not Individual Skills):** Like `obra/superpowers`, claude-forge is a curated multi-skill set rather than a single `SKILL.md`. Examples of bundled skills:

- **`auto-ship`** — full release pipeline (test → review → tag → release)
- **`frontend-design`** — distinctive UIs avoiding "AI slop"
- **`security-review`** — OWASP / secrets / dependency audit
- **`ci-bi`** — competitive intelligence + benchmarks
- **`blog-publish`** / **`daily-report`** / **`content-creator`** / **`generate-image`** — content workflows
- ...plus 16 more

**Social proof / vetting** (per the new CONTRIBUTING requirement):
- ✅ Submitted to `anthropics/claude-plugins-official` (in review)
- ✅ 4-way independent skeptical review completed 2026-04-23 (super-research / security / architect / codex)
- ✅ Active maintenance: weekly releases
- ✅ License: MIT, all open source, no paid funnel

**Why not "Individual Skills"?** Each skill has its own `SKILL.md`, but they're shipped as a coherent set with shared agent / hook infrastructure. Splitting them across the table would lose that "one install, everything works" property. Happy to also list individual skills there if you'd prefer.

Note on Skills/Commands hybrid: claude-forge documents its [Skills vs Commands boundary](https://github.com/sangrokjung/claude-forge/blob/main/docs/SKILLS-VS-COMMANDS.md) so users can pick the right entry point per workflow.

Happy to adjust placement, wording, or structure per your conventions.

— @sangrokjung
```

## Submission command (for maintainer to run)

```bash
# Step 1 — fork
gh repo fork travisvn/awesome-claude-skills --clone=false --remote=false

# Step 2 — clone, branch
git clone https://github.com/sangrokjung/awesome-claude-skills.git /tmp/cf-pr-travisvn
cd /tmp/cf-pr-travisvn
git checkout -b add-claude-forge

# Step 3 — Edit README.md
# Open README.md, find "### Collections & Libraries" (~line 99)
# Insert the bullet block after the "obra/superpowers-lab" entry (~line 110)
# Verify the bullet uses **[name](url)** - description format with sub-bullets

# Step 4 — verify
grep -c 'sangrokjung/claude-forge' README.md  # expect: >= 2

# Step 5 — commit, push, open PR
git add README.md
git commit -m "Add Claude Forge to Collections & Libraries"
git push -u origin add-claude-forge
gh pr create \
  --repo travisvn/awesome-claude-skills \
  --base main \
  --head sangrokjung:add-claude-forge \
  --title "Add Claude Forge — 24-skill production-grade distribution (Collections & Libraries)" \
  --body-file /Users/sangrok/claude-forge/docs/distribution/awesome-prs/travisvn.md
```

## PR URL
https://github.com/travisvn/awesome-claude-skills/pull/679

## Status
DRAFT — awaiting maintainer review and submission. Format matches existing `Collections & Libraries` entries (obra/superpowers, obra/superpowers-lab).
