# PR draft: Add claude-forge to rohitg00/awesome-claude-code-toolkit

## Target metadata
- Repo: rohitg00/awesome-claude-code-toolkit
- Star count at draft time: 1,520 (≈ 1.5K)
- Default branch: main
- Category to insert into: **`### All Plugins`** (under `## Plugins`) — table format with `| Plugin | Description |` columns
- Insertion position: alphabetical, between `claude-code-sessions` (`apappascs/claude-code-sessions`) and `cc-aws-keepalive` (`GeiserX/cc-aws-keepalive`). Note: the table appears mostly alphabetical but is not strictly enforced; place by first letter `c` near other `claude-*` entries.
- PR template requirements: `CONTRIBUTING.md` is light — see "PR template requirements" below

## PR template requirements (from CONTRIBUTING.md)

What to contribute:
- ✅ **Plugins** — go in `plugins/<plugin-name>/` with a `.claude-plugin/plugin.json` manifest *(only if hosted in the toolkit repo itself — external repos use the table without this)*
- ✅ **Update the README table** if adding a new item to any category

Guidelines:
- ✅ Keep files focused and single-purpose
- ✅ Clear, descriptive names
- ✅ Test before submitting
- ✅ "No generated attribution footers in files"

PR process:
1. Fork
2. Branch `feature/<your-feature>`
3. Make changes
4. Test locally
5. Commit message format: `Add new-skill: description`
6. Push, open PR

**Format observed in `### All Plugins` table:**

External repo (link to `github.com`):
```markdown
| [name](https://github.com/owner/repo) | Description with key features and metrics |
```

Internal plugin (link to `plugins/<name>/`):
```markdown
| [name](plugins/name/) | Description |
```

Featured row (separate `### Featured` table) includes a Stars column. We'd target `### All Plugins` (no stars column).

## Entry to add (verbatim, in the project's existing format)

Insert into `### All Plugins` table, in the `c*` cluster (the table is loosely alphabetical, sorted within `claude-*` entries):

```markdown
| [claude-forge](https://github.com/sangrokjung/claude-forge) | "oh-my-zsh for Claude Code". Complete toolkit: 11 agents, 34 commands, 25 skills, 15 hooks (covering 21 lifecycle events) + 9 opt-in examples, 9 rules, 4 MCP servers (playwright, context7, jina-reader, chrome-devtools@0.23.0), statusLine. One install via `curl ... install.sh` or `/plugin marketplace add sangrokjung/claude-forge`. Includes TDD workflow, multi-reviewer pipeline (codex/gemini/security/architect), Chrome DevTools Lighthouse audits, 4-way independent skeptical review. Submitted to anthropics/claude-plugins-official. MIT. |
```

## PR title
Add claude-forge: complete Claude Code toolkit (11 agents · 34 commands · 25 skills · 15 hooks · 4 MCP)

## PR body

```markdown
Hi Rohit! Adding [claude-forge](https://github.com/sangrokjung/claude-forge) to **All Plugins**.

**What it is:** A complete Claude Code toolkit, distributed as one install. Inventory:

- **11 agents** — planner, tdd-guide, code-reviewer, security-reviewer, architect, database-reviewer, build-error-resolver, doc-updater, refactor-cleaner, e2e-runner, verify-agent
- **34 slash commands** — covering TDD, review pipeline, deployment, content workflow, daily-report
- **25 skills** — auto-ship, frontend-design, security-review, ci-bi, blog-publish, daily-report, ...
- **15 hooks** (covering 21 lifecycle events) + 9 opt-in examples
- **9 rules** — coding-style, golden-principles, dev-team, etc.
- **4 MCP servers** — playwright, context7, jina-reader, chrome-devtools@0.23.0
- **statusLine** — context budget + project status indicator

**Install paths (covers both your "Featured" pattern and external repos):**
- One-line full install: `curl -fsSL https://raw.githubusercontent.com/sangrokjung/claude-forge/main/install.sh | bash`
- Lightweight plugin install: `/plugin marketplace add sangrokjung/claude-forge` then `/plugin install claude-forge`

**Vetting / social proof:**
- Submitted to [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) (in review)
- 4-way independent skeptical review completed 2026-04-23 (super-research / security / architect / codex)
- Weekly releases, active maintenance
- MIT license

I placed it in the `c*` cluster of `### All Plugins`. Happy to relocate or also add to `### Featured` if appropriate.

— @sangrokjung
```

## Submission command (for maintainer to run)

```bash
# Step 1 — fork
gh repo fork rohitg00/awesome-claude-code-toolkit --clone=false --remote=false

# Step 2 — clone, branch
git clone https://github.com/sangrokjung/awesome-claude-code-toolkit.git /tmp/cf-pr-rohitg00
cd /tmp/cf-pr-rohitg00
git checkout -b feature/add-claude-forge

# Step 3 — Edit README.md
# Find "### All Plugins" table (~line 83)
# Find the alphabetical position in the c-cluster (claude-context, claude-cost-optimizer, etc.)
# Insert the table row before the next non-c entry

# Step 4 — verify single new line was added
git diff --stat README.md  # expect: 1 file, 1 insertion(+), 0 deletions(-)
grep -c 'sangrokjung/claude-forge' README.md  # expect: 1

# Step 5 — commit (follow project's "Add new-skill: description" format)
git add README.md
git commit -m "Add claude-forge: complete Claude Code toolkit (11 agents · 34 commands · 25 skills · 15 hooks · 4 MCP)"
git push -u origin feature/add-claude-forge
gh pr create \
  --repo rohitg00/awesome-claude-code-toolkit \
  --base main \
  --head sangrokjung:feature/add-claude-forge \
  --title "Add claude-forge: complete Claude Code toolkit (11 agents · 34 commands · 25 skills · 15 hooks · 4 MCP)" \
  --body-file /Users/sangrok/claude-forge/docs/distribution/awesome-prs/rohitg00.md
```

## PR URL
https://github.com/rohitg00/awesome-claude-code-toolkit/pull/362

## Status
DRAFT — awaiting maintainer review and submission. Table-row format matches existing `### All Plugins` entries.
