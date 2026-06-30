# PR draft: Add claude-forge to ccplugins/awesome-claude-code-plugins

## Target metadata
- Repo: ccplugins/awesome-claude-code-plugins
- Star count at draft time: 754
- Default branch: main
- Category to insert into: **`### Workflow Orchestration`** (under `## Plugins`) — best fit because claude-forge is a multi-resource bundle/orchestrator distribution. Alternative: `### Development Engineering` if maintainer prefers single-domain placement.
- Insertion position: alphabetical, between `claude-desktop-extension` and `lyra` (i.e. inserted as `claude-forge` in the c-block)
- PR template requirements: No `CONTRIBUTING.md`. Format inferred from existing entries.

## Format observed in this list

The list uses a very minimal entry format — just the plugin name and a relative path:

```markdown
- [plugin-name](./plugins/plugin-name)
```

**Important:** Every existing entry in the README points to `./plugins/<name>` — meaning entries are **internal plugin folders inside this repo**, not external links to other repos.

This is a **contribution model**, not a list-pointer model: you fork, add your plugin folder under `./plugins/<name>/`, and add a line to README. Similar to ComposioHQ — see "Strategy" below.

## Strategy

Two options:

- **Strategy A (matches existing convention):** Fork, copy claude-forge's plugin manifest into `./plugins/claude-forge/.claude-plugin/plugin.json`, mirror minimal structure (manifests + sample slash commands), and add the line to README.
- **Strategy B (external link, breaking convention):** Submit a PR with `- [claude-forge](https://github.com/sangrokjung/claude-forge)` pointing externally. Risk: rejected for not matching format.

**Recommendation:** Strategy A. Cost is small — copy the existing `.claude-plugin/marketplace.json` + `.claude-plugin/plugin.json` into the fork and let users discover the full repo via the manifest's `homepage` / `repository` URLs.

## Entry to add (verbatim, in the project's existing format)

Inside `### Workflow Orchestration`, alphabetically between `claude-desktop-extension` and `lyra`:

```markdown
- [claude-forge](./plugins/claude-forge)
```

For maintainer reference, the corresponding plugin folder structure to add:

```
plugins/claude-forge/
  .claude-plugin/
    plugin.json          # mirror of sangrokjung/claude-forge/.claude-plugin/plugin.json
    marketplace.json     # mirror of sangrokjung/claude-forge/.claude-plugin/marketplace.json
  README.md              # 1-page description + install commands + link back to upstream
```

The plugin.json should declare:
- `name`: `claude-forge`
- `version`: `3.0.1`
- `description`: `oh-my-zsh for Claude Code — 11 agents · 34 commands · 25 skills · 15 hooks · 9 rules · 4 MCP servers in one install`
- `repository`: `https://github.com/sangrokjung/claude-forge`
- `license`: `MIT`
- `commands`: paths under upstream repo
- `agents`: paths under upstream repo

Install command for end users:
```
/plugin marketplace add sangrokjung/claude-forge
/plugin install claude-forge
```

## PR title
Add claude-forge to Workflow Orchestration

## PR body

```markdown
Hi! Adding [claude-forge](https://github.com/sangrokjung/claude-forge) under **Workflow Orchestration**.

**Why Workflow Orchestration:** claude-forge is a multi-resource distribution that orchestrates 11 agents, 34 commands, 25 skills, 15 hooks, 9 rules, and 4 MCP servers as one installable plugin — closer in shape to `ultrathink` and `studio-coach` than to the single-domain entries in other categories. Happy to relocate to **Development Engineering** if you prefer single-domain placement.

**What's added:**
- README line: `- [claude-forge](./plugins/claude-forge)` in Workflow Orchestration
- `plugins/claude-forge/.claude-plugin/plugin.json` — manifest mirror
- `plugins/claude-forge/.claude-plugin/marketplace.json` — marketplace mirror
- `plugins/claude-forge/README.md` — 1-page description + install commands + link to upstream

**Plugin manifests in this repo point to upstream:** `https://github.com/sangrokjung/claude-forge`. Source of truth lives there; this fork tracks the plugin metadata only.

**End-user install:**
```
/plugin marketplace add sangrokjung/claude-forge
/plugin install claude-forge
```

**Vetting:**
- Submitted to [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) (in review)
- 4-way independent skeptical review completed 2026-04-23
- MIT license, weekly releases

— @sangrokjung
```

## Submission command (for maintainer to run)

```bash
# Step 1 — fork
gh repo fork ccplugins/awesome-claude-code-plugins --clone=false --remote=false

# Step 2 — clone, branch
git clone https://github.com/sangrokjung/awesome-claude-code-plugins.git /tmp/cf-pr-ccplugins
cd /tmp/cf-pr-ccplugins
git checkout -b add-claude-forge

# Step 3 — Create the plugin folder + mirror manifests
mkdir -p plugins/claude-forge/.claude-plugin
cp /Users/sangrok/claude-forge/.claude-plugin/plugin.json plugins/claude-forge/.claude-plugin/
cp /Users/sangrok/claude-forge/.claude-plugin/marketplace.json plugins/claude-forge/.claude-plugin/

# Create README.md for the in-repo plugin folder
cat > plugins/claude-forge/README.md <<'EOF'
# claude-forge

Production-grade Claude Code distribution — 11 agents · 34 commands · 25 skills · 15 hooks · 9 rules · 4 MCP servers.

**Source of truth:** https://github.com/sangrokjung/claude-forge

## Install

```bash
/plugin marketplace add sangrokjung/claude-forge
/plugin install claude-forge
```

Or full install (covers agents/hooks/rules/MCP/statusLine):

```bash
curl -fsSL https://raw.githubusercontent.com/sangrokjung/claude-forge/main/install.sh | bash
```

## License
MIT (see upstream repo)
EOF

# Step 4 — Edit README.md (insert line in Workflow Orchestration alphabetically)
# Open README.md, find "### Workflow Orchestration" (~line 57)
# Insert "- [claude-forge](./plugins/claude-forge)" between "claude-desktop-extension" and "lyra"

# Step 5 — verify
grep -c 'plugins/claude-forge' README.md  # expect: 1

# Step 6 — commit, push, open PR
git add plugins/claude-forge README.md
git commit -m "Add claude-forge to Workflow Orchestration"
git push -u origin add-claude-forge
gh pr create \
  --repo ccplugins/awesome-claude-code-plugins \
  --base main \
  --head sangrokjung:add-claude-forge \
  --title "Add claude-forge to Workflow Orchestration" \
  --body-file /Users/sangrok/claude-forge/docs/distribution/awesome-prs/ccplugins.md
```

## PR URL
(empty — fill after maintainer submits)

## Status
DRAFT — awaiting maintainer review and submission. **Strategy A (in-repo plugin folder mirror) recommended over Strategy B (external link).**
