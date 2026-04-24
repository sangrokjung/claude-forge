# Contributing to Claude Forge

Thank you for your interest in contributing to Claude Forge!

## How to Contribute

1. **Fork** the repository
2. **Create a branch** for your feature or fix
   ```bash
   git checkout -b feat/your-feature
   ```
3. **Make your changes** following the coding standards below
4. **Commit** with conventional commit messages
   ```bash
   git commit -m "feat: add new agent for X"
   ```
5. **Push** and create a **Pull Request**

## Adding New Components

### Agents (`agents/`)

**File structure:**

```markdown
# Part of Claude Forge — github.com/sangrokjung/claude-forge
---
name: my-agent
description: One-line description of the agent's purpose
tools: ["Read", "Grep", "Glob"]
model: opus
---

<Agent_Prompt>
<Role>
You are a [role description]...
</Role>

<Constraints>
- Constraint 1
- Constraint 2
</Constraints>

<Investigation_Protocol>
1. Step 1
2. Step 2
</Investigation_Protocol>

<Output_Format>
[Define expected output structure]
</Output_Format>
</Agent_Prompt>
```

**Guidelines:**
- One `.md` file per agent
- Follow the `<Agent_Prompt>` structure with `<Role>`, `<Constraints>`, `<Investigation_Protocol>`, `<Output_Format>` sections
- Specify `model` (opus for deep analysis, sonnet for fast execution, haiku for quick tasks)
- Include the Claude Forge attribution header at the top
- Keep agent descriptions focused and specific

### Commands (`commands/`)

**Simple command (single file):**

```markdown
---
description: What this command does
argument-hint: "<optional-arg>"
allowed-tools: ["Read", "Bash", "Glob"]
---

# /my-command

Instructions for Claude Code to follow when this command is invoked.

## Steps
1. Step 1
2. Step 2
```

**Complex command (directory with SKILL.md):**

```
commands/my-command/
  ├── SKILL.md          # Entry point
  └── references/       # Supplementary docs
      └── guide.md
```

### Skills (`skills/`)

Each skill is a directory with `SKILL.md` as entry point:

```
skills/my-skill/
  ├── SKILL.md          # Entry point
  ├── hooks/            # Optional event hooks
  │   └── pre-check.sh
  └── references/       # Supplementary docs
      └── patterns.md
```

### Hooks (`hooks/`)

- Shell scripts (`.sh`) that execute on Claude Code events
- **Must complete within 5 seconds** -- keep hooks lightweight
- Add timeout in `settings.json` for potentially slow hooks
- Test on both macOS and Linux/WSL

### Rules (`rules/`)

- Markdown files loaded automatically every session
- Keep rules concise and actionable
- Use `(CRITICAL)` suffix for mandatory rules
- Rules should be self-contained and not depend on other rules

## Coding Standards

- Follow `rules/coding-style.md` conventions
- Immutability: never mutate objects
- Small files (< 800 lines), small functions (< 50 lines)
- Validate inputs at system boundaries (zod schemas)
- No hardcoded secrets

## Commit Messages

Format: `<type>: <description>`

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

## Contributor Benefits

- **README recognition**: All contributors are permanently featured in the Contributors section via [contrib.rocks](https://contrib.rocks)
- **Agent author credit**: When you create a new agent, your GitHub username is credited in the agent file's frontmatter (`author` field)
- **Good First Issues**: Look for issues labeled `good first issue` for a great starting point

## Publishing to the Plugin Directory

Since v3.0.1 claude-forge is distributed as a Claude Code plugin. That adds a short
checklist whenever you cut a release or register with a marketplace.

### Version Bump Checklist (run on every release)

Every version bump touches **three fields across two files**. The CI job
`marketplace-schema` fails the build if any of them drift apart.

1. `.claude-plugin/plugin.json` → `.version`
2. `.claude-plugin/marketplace.json` → `.version`
3. `.claude-plugin/marketplace.json` → `.plugins[].version` for the `claude-forge` entry

Example (`3.0.1` → `3.0.2`):

```bash
jq '.version = "3.0.2"' .claude-plugin/plugin.json | sponge .claude-plugin/plugin.json
jq '.version = "3.0.2"
  | .plugins = (.plugins | map(if .name == "claude-forge" then .version = "3.0.2" else . end))' \
  .claude-plugin/marketplace.json | sponge .claude-plugin/marketplace.json
```

Also update any count fields embedded in `description` when component inventory changes
(agents, commands, skills, hooks, rules, MCP servers).

### Pre-release QA

Before tagging a release, all of the following must be green:

- [ ] `./install.sh --dry-run` succeeds with no missing paths
- [ ] GitHub Actions `validate.yml` passes all 5 jobs
      (`json`, `marketplace-schema`, `frontmatter`, `installer`, `security`)
- [ ] `claude mcp list` shows 0 unexpected failures for default servers
- [ ] Local smoke: run `/plugin marketplace add sangrokjung/claude-forge` followed by
      `/plugin install claude-forge` in a throwaway Claude Code session and confirm the
      expected `version` lands. (This exercises the same path a first-time user takes.
      See [`docs/PLUGIN-VS-INSTALL-SH.md`](docs/PLUGIN-VS-INSTALL-SH.md) for what the
      plugin loader does and does not cover.)

### Release Tag & GitHub Release

After the PR is merged to `main`:

```bash
git checkout main && git pull
git tag -a v3.0.2 -m "v3.0.2: <one-line summary>"
git push origin v3.0.2
gh release create v3.0.2 --generate-notes
```

GitHub's auto-generated notes are fine for patch releases. For major/minor releases,
attach a `MIGRATION.md` diff and a short "what's new" header.

### Submitting to the Official Directory

The public Anthropic directory lives at
[`github.com/anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official),
with community entries under `external_plugins/`. To propose inclusion:

1. Open a submission at <https://clau.de/plugin-directory-submission>.
2. Reference this repo's `docs/MARKETPLACE-SUBMISSION.md` (the prepared submission
   packet — contains the required metadata and the security review summary).
3. Once approved, users can install via either path:
   - Self-hosted marketplace (two-step, available today):
     `/plugin marketplace add sangrokjung/claude-forge` → `/plugin install claude-forge`
   - Official directory (after approval):
     `/plugin install claude-forge@claude-plugins-official`

Until approved, the self-hosted-marketplace path is the canonical one and must keep
working. Note the scope limitation documented in
[`docs/PLUGIN-VS-INSTALL-SH.md`](docs/PLUGIN-VS-INSTALL-SH.md): the plugin loader
currently wires only Commands + most Skills; Agents / Hooks / Rules / MCP / statusLine
still require `./install.sh`.

### PR Template Additions (recommended)

When opening a release PR, include:

- [ ] Version bumped in all 3 fields (plugin.json, marketplace.json root,
      marketplace.json plugins[].version)
- [ ] Breaking change? → link a Migration note in `MIGRATION.md`
- [ ] New MCP server added? → documented in `docs/MCP-MIGRATION.md` with license/source
- [ ] CI `marketplace-schema` job green locally (run via `act` or push to a draft PR)

## Skills vs Commands

Claude Forge v3.0 follows a hybrid policy: `skills/<name>/SKILL.md` hosts auto-invocable knowledge and reusable workflows, while `commands/*.md` hosts explicit side-effect actions that the user times by typing `/name`. If the surface benefits from bundled `references/` or should be discovered automatically, it is a skill; if it commits, pushes, deploys, or notifies, it is a command.

See [`docs/SKILLS-VS-COMMANDS.md`](docs/SKILLS-VS-COMMANDS.md) for the full policy, gray-zone examples, frontmatter standards, and the authoring checklist.

## Questions?

Open an issue on [GitHub](https://github.com/sangrokjung/claude-forge/issues).
