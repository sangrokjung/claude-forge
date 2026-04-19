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

## Skills vs Commands

Claude Forge v3.0 follows a hybrid policy: `skills/<name>/SKILL.md` hosts auto-invocable knowledge and reusable workflows, while `commands/*.md` hosts explicit side-effect actions that the user times by typing `/name`. If the surface benefits from bundled `references/` or should be discovered automatically, it is a skill; if it commits, pushes, deploys, or notifies, it is a command.

See [`docs/SKILLS-VS-COMMANDS.md`](docs/SKILLS-VS-COMMANDS.md) for the full policy, gray-zone examples, frontmatter standards, and the authoring checklist.

## Questions?

Open an issue on [GitHub](https://github.com/sangrokjung/claude-forge/issues).
