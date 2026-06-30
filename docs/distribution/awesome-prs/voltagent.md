# PR draft: Add claude-forge to VoltAgent/awesome-claude-code-subagents

## Target metadata
- Repo: VoltAgent/awesome-claude-code-subagents
- Star count at draft time: 18,966 (≈ 19K)
- Default branch: main
- Category to insert into: This list is **structurally different** — see "Important format note" below
- Insertion position: per category, alphabetical (e.g. inside `## 04. Quality & Security` between `code-reviewer` and `compliance-auditor`)
- PR template requirements: `CONTRIBUTING.md` is strict — see "PR template requirements" below

## Important format note (CRITICAL — read before submitting)

VoltAgent does **not** accept a single bullet pointing to an external repo. Per `CONTRIBUTING.md`, every entry must be:

1. A standalone agent `.md` file under `categories/<category>/<agent-name>.md`
2. An entry in the **Main README.md** under that category section, in alphabetical order, in the format `- [**agent-name**](path/to/agent.md) - Brief description`
3. An entry in the **Category README.md** with detailed description + Quick Selection Guide table update + Common Technology Stacks update if applicable
4. A **plugin version bump** in `categories/<category>/.claude-plugin/plugin.json` and matching update in `.claude-plugin/marketplace.json`

This means we cannot drop a one-line "Claude Forge" pointer to our external repo. We must contribute either:

- **Strategy A (recommended for first PR):** Contribute claude-forge's most distinctive 1-2 agents as standalone files in the appropriate categories. Then mention claude-forge as the source in each agent file's frontmatter / footer.
- **Strategy B (riskier — likely rejected):** Open an issue first asking whether external-distribution links are acceptable in any section. If yes, then PR a single line. If no, fall back to Strategy A.

**Recommendation:** Strategy A, contributing 2 agents that don't already exist in the list:
- `verify-agent` (Quality & Security category) — production-test verifier with TDD-aware loop. Not present in voltagent's roster.
- `build-error-resolver` (Developer Experience category) — closes the gap between "tests fail" and "fix the dependency / config / version mismatch". Not present in voltagent's roster.

## PR template requirements (from CONTRIBUTING.md)

When adding a new agent, you MUST update these files:

1. **Main README.md** — add agent link in the appropriate category section, alphabetical order, format `- [**agent-name**](path/to/agent.md) - Brief description`
2. **Category README.md** (e.g. `categories/04-quality-security/README.md`) — add detailed agent description, update Quick Selection Guide table, update Common Technology Stacks if applicable
3. **Your Agent File** (e.g. `categories/04-quality-security/verify-agent.md`) — follow standard template (Role / Expertise / MCP Tools / Communication Protocol / Core Capabilities / Examples / Best Practices)
4. **Plugin version bump** — `categories/<category>/.claude-plugin/plugin.json` version + sync to `.claude-plugin/marketplace.json`

PR process:
1. Fork
2. Branch `feature/<agent-name>` (NOT `add-claude-forge`)
3. All 4 file updates above
4. Verify all links work
5. Submit PR with clear description

## Entry to add (verbatim — Strategy A, two agents)

### Entry 1 — Main `README.md`, inside `### [04. Quality & Security]`, alphabetically between `test-automator` and `ui-ux-tester`

```markdown
- [**verify-agent**](categories/04-quality-security/verify-agent.md) - Production-test verifier that closes the gap between "tests written" and "tests actually pass against running code"
```

### Entry 2 — Main `README.md`, inside `### [06. Developer Experience]`, alphabetically between `build-engineer` and `cli-developer`

```markdown
- [**build-error-resolver**](categories/06-developer-experience/build-error-resolver.md) - Specialist that diagnoses and fixes build failures (dependency mismatches, config drift, version pinning, lockfile conflicts)
```

### Companion content — claude-forge attribution

In each new agent's `.md` file frontmatter / footer, include an attribution block so users can find the source distribution:

```markdown
---
source: https://github.com/sangrokjung/claude-forge
license: MIT
maintainer: "@sangrokjung"
part_of: "Claude Forge — production-grade Claude Code distribution (11 agents · 34 commands · 25 skills · 15 hooks)"
---
```

## PR title
Add `verify-agent` and `build-error-resolver` (from Claude Forge distribution)

## PR body

```markdown
Hi VoltAgent team! Adding two agents from the [Claude Forge](https://github.com/sangrokjung/claude-forge) distribution that fill gaps in the current roster:

1. **`verify-agent`** → `categories/04-quality-security/`
   - Closes the "tests written but never run" gap. Spawns a fresh subagent, runs the full test suite, captures verbatim output, and refuses to mark a feature complete until exit code 0.
   - Complements your existing `test-automator` (which writes tests) and `qa-expert` (which designs test strategy).

2. **`build-error-resolver`** → `categories/06-developer-experience/`
   - Specialist for the "I get a build error and it's not in my code" class of problems — dependency mismatches, lockfile conflicts, config drift, version pinning issues.
   - Complements your existing `build-engineer` (build system design) and `dependency-manager` (long-term hygiene).

**Files updated per CONTRIBUTING.md:**
- ✅ Main `README.md` — alphabetically inserted in correct category sections
- ✅ Category `README.md` — added descriptions + Quick Selection Guide rows
- ✅ Agent `.md` files — full template with frontmatter, MCP tools, examples
- ✅ `categories/04-quality-security/.claude-plugin/plugin.json` version bumped
- ✅ `categories/06-developer-experience/.claude-plugin/plugin.json` version bumped
- ✅ `.claude-plugin/marketplace.json` synced

**Source attribution:** Both agents originated in [Claude Forge](https://github.com/sangrokjung/claude-forge), an MIT-licensed Claude Code distribution. Frontmatter in each `.md` file links back so users can find the full set (11 agents · 34 commands · 25 skills · 15 hooks).

Happy to split this into two PRs if you prefer one agent per PR. Also happy to adjust naming, descriptions, or relocation — your call.

— @sangrokjung
```

## Submission command (for maintainer to run)

```bash
# Step 1 — fork
gh repo fork VoltAgent/awesome-claude-code-subagents --clone=false --remote=false

# Step 2 — clone, branch
git clone https://github.com/sangrokjung/awesome-claude-code-subagents.git /tmp/cf-pr-voltagent
cd /tmp/cf-pr-voltagent
git checkout -b feature/verify-agent-and-build-error-resolver

# Step 3 — copy the two agent .md files (port from claude-forge agent definitions)
mkdir -p categories/04-quality-security categories/06-developer-experience
cp /Users/sangrok/claude-forge/agents/verify-agent.md categories/04-quality-security/verify-agent.md
cp /Users/sangrok/claude-forge/agents/build-error-resolver.md categories/06-developer-experience/build-error-resolver.md
# (Adapt frontmatter to match the VoltAgent template — they require Role/Expertise/MCP Tools/Communication Protocol sections)

# Step 4 — edit Main README.md alphabetically inside the two category sections
# Step 5 — edit categories/04-quality-security/README.md and categories/06-developer-experience/README.md
# Step 6 — bump versions in categories/<both>/.claude-plugin/plugin.json
# Step 7 — sync .claude-plugin/marketplace.json

# Step 8 — verify links
grep -rE 'verify-agent|build-error-resolver' README.md categories/*/README.md

# Step 9 — commit, push, open PR
git add -A
git commit -m "Add verify-agent and build-error-resolver (from Claude Forge)"
git push -u origin feature/verify-agent-and-build-error-resolver
gh pr create \
  --repo VoltAgent/awesome-claude-code-subagents \
  --base main \
  --head sangrokjung:feature/verify-agent-and-build-error-resolver \
  --title "Add verify-agent and build-error-resolver (from Claude Forge distribution)" \
  --body-file /Users/sangrok/claude-forge/docs/distribution/awesome-prs/voltagent.md
```

## PR URL
(empty — fill after maintainer submits)

## Status
DRAFT — awaiting maintainer review and submission. **Strategy A (contribute 2 agents) recommended over Strategy B (single external link).**
