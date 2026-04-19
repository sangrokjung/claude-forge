# Claude Forge — Official Marketplace Submission Guide

> Last updated: 2026-03-16
> Based on: `anthropics/claude-plugins-official` repository analysis

## Overview

Anthropic maintains an official plugin directory at [`anthropics/claude-plugins-official`](https://github.com/anthropics/claude-plugins-official). It contains two categories:

- **`/plugins`** — Internal plugins developed by Anthropic (29 plugins as of 2026-03)
- **`/external_plugins`** — Third-party plugins from partners and community (13 plugins including Asana, Context7, Firebase, GitHub, GitLab, Greptile, Laravel Boost, Linear, Playwright, Serena, Slack, Stripe, Supabase)

## Submission Method

### External Plugin Submission

Third-party plugins are submitted via the **[Plugin Directory Submission Form](https://clau.de/plugin-directory-submission)**.

This is the official channel — there is no PR-based submission process for external plugins. The form routes to Anthropic's internal review pipeline.

### What to Expect

1. Submit the form with your plugin repository URL and metadata
2. Anthropic reviews for quality and security standards
3. If approved, a minimal entry is created in `external_plugins/` pointing to your repository
4. Your plugin becomes discoverable via `/plugin > Discover` in Claude Code

## Required Plugin Structure

Based on the official example-plugin and existing external plugins:

```
claude-forge/
├── .claude-plugin/
│   └── plugin.json        # REQUIRED — minimal metadata
├── .mcp.json              # Optional — MCP server config (flat format)
├── commands/              # Optional — slash commands
│   └── command-name.md
├── agents/                # Optional — agent definitions
│   └── agent-name.md
├── skills/                # Optional — skill definitions
│   └── skill-name/
│       └── SKILL.md
├── rules/                 # Optional — auto-loaded rules
│   └── rule-name.md
├── LICENSE                # Recommended
└── README.md              # Recommended
```

### `plugin.json` (Minimal Required Format)

```json
{
  "name": "claude-forge",
  "description": "oh-my-zsh for Claude Code — 11 agents, 40 commands, 15 skills, 15 hooks, 9 rules in one install",
  "author": {
    "name": "Sangrok Jung"
  }
}
```

Official schema only requires `name`, `description`, and `author.name`. Extra fields (`version`, `repository`, `keywords`, etc.) are ignored but not harmful.

### `.mcp.json` (Flat Format)

```json
{
  "context7": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@upstash/context7-mcp@latest"]
  },
  "memory": {
    "type": "stdio",
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-memory"]
  }
}
```

Key difference from Claude Forge's current `mcp-servers.json`: official format is **flat** (no `"servers"` wrapper, no `"description"` field).

## Pre-Submission Checklist

### Must Have

- [ ] `.claude-plugin/plugin.json` with `name`, `description`, `author`
- [ ] `README.md` with installation instructions and usage guide
- [ ] `LICENSE` file (MIT recommended for open-source)
- [ ] Working installation process (via `claude plugin install` or manual)
- [ ] No hardcoded secrets or API keys in any files
- [ ] All hook scripts use safe patterns (no destructive operations)

### Should Have

- [ ] `.mcp.json` in official flat format (if MCP servers are included)
- [ ] All command files have `---` YAML frontmatter with `description`
- [ ] All skill folders contain `SKILL.md` with frontmatter
- [ ] Agent files use standard `---` frontmatter format
- [ ] Security review of all hook scripts
- [ ] No `settings.json` at plugin root (not auto-loaded — use `install.sh` for merging)

### Nice to Have

- [ ] `CONTRIBUTING.md`
- [ ] `CODE_OF_CONDUCT.md`
- [ ] `SECURITY.md`
- [ ] Screenshots or demo GIFs in README
- [ ] CI/CD pipeline for validation
- [ ] Changelog

## Claude Forge Specific Gaps

Based on `STRUCTURE-VALIDATION.md` analysis:

| Gap | Priority | Fix |
|-----|----------|-----|
| No `.mcp.json` at root | HIGH | Create flat-format `.mcp.json` from `mcp-servers.json` |
| 3 commands without frontmatter | MEDIUM | Add `---` frontmatter to `build-fix.md`, `refactor-clean.md`, `eval.md` |
| Agent files have comment before frontmatter | LOW | Remove `# Part of Claude Forge` line (optional) |
| `plugin.json` has extra fields | LOW | Harmless, no fix needed |

## Installation Methods After Directory Listing

Once listed in the official directory, users can install via:

```bash
# From official directory
claude plugin install claude-forge@claude-plugin-directory

# Or browse and discover
# /plugin > Discover
```

For self-hosted marketplace (before official listing):

```bash
# Direct GitHub install
claude plugin install sangrokjung/claude-forge

# Or via install script
curl -fsSL https://raw.githubusercontent.com/sangrokjung/claude-forge/main/install.sh | bash
```

## Security Review Expectations

Anthropic reviews plugins for:

1. **No malicious code** — hook scripts, MCP servers, and install scripts are scrutinized
2. **Safe permissions** — `deny` rules should prevent destructive operations
3. **No data exfiltration** — hooks should not send data to external services without user consent
4. **Transparent behavior** — README must accurately describe what the plugin does
5. **No excessive permissions** — `allow` list should be minimal for the plugin's purpose

### Claude Forge Security Strengths

- Comprehensive `deny` list (50+ patterns) in `settings.json`
- `db-guard.sh` — blocks DROP/TRUNCATE/DELETE without WHERE
- `remote-command-guard.sh` — blocks SSH/remote execution
- `output-secret-filter.sh` — filters secrets from output
- `rate-limiter.sh` — prevents MCP abuse
- MIT license for full transparency

## External Plugin Examples (Reference)

| Plugin | What's Included | Size |
|--------|----------------|------|
| `context7` | `.claude-plugin/plugin.json` + `.mcp.json` | 2 files |
| `supabase` | `.claude-plugin/plugin.json` + `.mcp.json` | 2 files |
| `playwright` | `.claude-plugin/plugin.json` + `.mcp.json` | 2 files |
| `firebase` | `.claude-plugin/plugin.json` + `.mcp.json` | 2 files |

Most external plugins in the official directory are **minimal wrappers** that only include `plugin.json` and `.mcp.json`. Claude Forge is significantly larger (11 agents, 40 commands, 15 skills, 15 hooks, 9 rules) and would be one of the most comprehensive plugins in the directory.

## Timeline Expectations

- Form submission: Immediate
- Initial review: Unknown (Anthropic does not publish SLAs)
- Listing: After approval
- Updates: Managed via your GitHub repository (the directory entry points to your repo)

## Recommended Submission Strategy

1. **Immediate**: Fix HIGH priority gaps (create `.mcp.json`)
2. **Before submission**: Fix MEDIUM gaps (command frontmatter)
3. **Submit**: Via the [plugin directory submission form](https://clau.de/plugin-directory-submission)
4. **Parallel**: Maintain self-hosted marketplace via `marketplace.json` for users who prefer direct installation
5. **After listing**: Keep GitHub repo as source of truth — directory entry points to it
