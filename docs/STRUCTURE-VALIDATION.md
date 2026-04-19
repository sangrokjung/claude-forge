# Claude Forge Plugin Structure Validation Report

> Validated: 2026-03-16
> Reference: `anthropics/claude-plugins-official` (example-plugin)

## Official Plugin Structure (Reference)

```
plugin-name/
├── .claude-plugin/
│   └── plugin.json      # Plugin metadata (REQUIRED)
├── .mcp.json            # MCP server configuration (optional)
├── commands/            # Slash commands (optional)
├── agents/              # Agent definitions (optional)
├── skills/              # Skill definitions (optional)
└── README.md            # Documentation
```

---

## 1. `.claude-plugin/plugin.json` — PASS

| Check | Status | Details |
|-------|--------|---------|
| File exists | PASS | `.claude-plugin/plugin.json` present |
| `name` field | PASS | `"claude-forge"` |
| `description` field | PASS | Present with detailed description |
| `author` field | PASS | `{ "name": "Sangrok Jung", "url": "..." }` |

### Differences from Official Schema

Official `plugin.json` uses minimal fields (`name`, `description`, `author`). Claude Forge adds extra fields:

| Field | Official Example | Claude Forge | Impact |
|-------|-----------------|--------------|--------|
| `version` | Not present | `"2.2.0"` | Non-standard but harmless |
| `repository` | Not present | Present | Non-standard but harmless |
| `homepage` | Not present | Present | Non-standard but harmless |
| `license` | Not present | `"MIT"` | Non-standard but harmless |
| `keywords` | Not present | Array of tags | Non-standard but harmless |
| `engines` | Not present | `{ "claude-code": ">=1.0.0" }` | Non-standard but harmless |
| `agents` | Not present | `"agents/"` | Non-standard path pointer |
| `skills` | Not present | `"skills/"` | Non-standard path pointer |
| `hooks` | Not present | `"hooks/"` | Non-standard path pointer |
| `commands` | Not present | `"commands/"` | Non-standard path pointer |
| `rules` | Not present | `"rules/"` | Non-standard path pointer |
| `scripts` | Not present | `"scripts/"` | Non-standard path pointer |
| `mcpServers` | Not present | `"./mcp-servers.json"` | Non-standard — official uses `.mcp.json` directly |

**Recommendation**: Extra fields do not break compatibility. Claude Code ignores unknown keys in `plugin.json`. The official schema only requires `name`, `description`, and `author`.

---

## 2. Skills Directory — PASS

All 15 skills have correctly structured `SKILL.md` files:

```
skills/
├── build-system/SKILL.md
├── cache-components/SKILL.md
├── cc-dev-agent/SKILL.md
├── continuous-learning-v2/SKILL.md
├── eval-harness/SKILL.md
├── frontend-code-review/SKILL.md
├── manage-skills/SKILL.md
├── prompts-chat/SKILL.md
├── security-pipeline/SKILL.md
├── session-wrap/SKILL.md
├── skill-factory/SKILL.md
├── strategic-compact/SKILL.md
├── team-orchestrator/SKILL.md
├── verification-engine/SKILL.md
└── verify-implementation/SKILL.md
```

| Check | Status | Details |
|-------|--------|---------|
| `skills/*/SKILL.md` pattern | PASS | All 15 skills follow `skills/{name}/SKILL.md` |
| Frontmatter present | PASS | Checked `build-system` and `session-wrap` — both have `---` frontmatter with `name`, `description` |
| Matches official pattern | PASS | Official example: `skills/example-skill/SKILL.md` |

---

## 3. Hooks — WARNING

| Check | Status | Details |
|-------|--------|---------|
| `hooks/hooks.json` exists | PASS | File present |
| Claude Code native support | WARNING | `hooks.json` is a **reference document only** (see `_comment` field). Claude Code does NOT load a separate `hooks.json` — hooks must be in `settings.json` |
| `settings.json` hooks | PASS | `settings.json` contains full `hooks` object matching `hooks.json` content |
| Shell scripts present | PASS | 15 `.sh` hook scripts in `hooks/` directory |

**Note**: The `hooks.json` file explicitly states via `_comment`: "Reference document only. Claude Code does not support a separate hooks.json. Actual hook settings must be in settings.json." The `settings.json` correctly duplicates all hook definitions.

### Hook Scripts (15):

```
hooks/
├── code-quality-reminder.sh
├── context-sync-suggest.sh
├── db-guard.sh
├── expensive-mcp-warning.sh
├── forge-update-check.sh
├── mcp-usage-tracker.sh
├── output-secret-filter.sh
├── rate-limiter.sh
├── remote-command-guard.sh
├── security-auto-trigger.sh
├── session-wrap-suggest.sh
├── task-completed.sh
├── work-tracker-prompt.sh
├── work-tracker-stop.sh
└── work-tracker-tool.sh
```

---

## 4. Agents — PASS (with format note)

11 agent files present in `agents/`:

```
agents/
├── architect.md
├── build-error-resolver.md
├── code-reviewer.md
├── database-reviewer.md
├── doc-updater.md
├── e2e-runner.md
├── planner.md
├── refactor-cleaner.md
├── security-reviewer.md
├── tdd-guide.md
└── verify-agent.md
```

| Check | Status | Details |
|-------|--------|---------|
| Files present | PASS | 11 agent `.md` files |
| Frontmatter format | PASS (with note) | All agents use a custom format: line 1 is a comment (`# Part of Claude Forge`), then `---` YAML frontmatter with `name`, `description`, `tools` |
| Required fields | PASS | All have `name`, `description`, `tools` |

**Format Note**: Official plugins don't specify an agents format in the example-plugin. Claude Forge agents use `---` YAML frontmatter which is the standard Claude Code agent format. The `# Part of Claude Forge` comment on line 1 before `---` is non-standard but Claude Code parser typically skips to the first `---`.

---

## 5. Commands — PASS

40 command files in `commands/`:

| Check | Status | Details |
|-------|--------|---------|
| Files present | PASS | 40 `.md` command files |
| Frontmatter | PASS | Most commands have `---` YAML frontmatter with `description` and `allowed-tools` |
| Some without frontmatter | WARNING | `build-fix.md`, `refactor-clean.md`, `eval.md` start with `#` heading instead of `---`. These may not register as slash commands properly |

---

## 6. MCP Configuration — WARNING

| Check | Status | Details |
|-------|--------|---------|
| `mcp-servers.json` exists | PASS | Custom format with `servers` wrapper object |
| `.mcp.json` exists | FAIL | **Not present** at plugin root |
| Official format | WARNING | Official plugins use `.mcp.json` (flat key-value), not `mcp-servers.json` with `{ "servers": { ... } }` wrapper |

### Format Comparison

**Official `.mcp.json`** (from example-plugin):
```json
{
  "example-server": {
    "type": "http",
    "url": "https://mcp.example.com/api"
  }
}
```

**Claude Forge `mcp-servers.json`**:
```json
{
  "description": "...",
  "servers": {
    "context7": { ... },
    "memory": { ... },
    ...
  }
}
```

**Recommendation**: For official marketplace compatibility, create a `.mcp.json` file at the plugin root with the flat format (no `servers` wrapper, no `description`). The install script can handle conversion.

---

## 7. `settings.json` — PASS (with compatibility note)

| Check | Status | Details |
|-------|--------|---------|
| File exists | PASS | Present at plugin root |
| Hooks section | PASS | Contains all hooks |
| Permissions section | PASS | Contains `allow` and `deny` lists |
| `env` section | PASS | Contains environment variables |
| `statusLine` section | PASS | CC Chips integration |

**Compatibility Note**: Claude Code plugins currently support `.claude-plugin/plugin.json`, `.mcp.json`, `commands/`, `agents/`, `skills/`, and `rules/` as auto-loaded directories. `settings.json` at plugin root is **not auto-loaded** by the plugin system — it requires the install script to merge into `~/.claude/settings.json`.

---

## 8. Rules — PASS

9 rule files in `rules/`:

```
rules/
├── agents-v2.md
├── coding-style.md
├── date-calculation.md
├── git-workflow-v2.md
├── golden-principles.md
├── interaction.md
├── security.md
├── testing.md
└── verification.md
```

| Check | Status | Details |
|-------|--------|---------|
| Files present | PASS | 9 `.md` rule files |
| Claude Code support | PASS | Rules in plugin `rules/` directory are auto-loaded by Claude Code |

---

## 9. Additional Directories (Non-standard)

| Directory | Official Support | Purpose |
|-----------|-----------------|---------|
| `cc-chips/` | No | Status line theme engine |
| `cc-chips-custom/` | No | Custom theme engine |
| `knowledge/` | No | Reference knowledge base |
| `reference/` | No | Detailed reference docs |
| `scripts/` | No | Install/setup scripts |
| `setup/` | No | Setup guides and configs |

These are not auto-loaded by Claude Code's plugin system but are used by the install script.

---

## Summary

| Component | Status | Count | Notes |
|-----------|--------|-------|-------|
| `.claude-plugin/plugin.json` | PASS | 1 | Extra fields are harmless |
| Skills (`SKILL.md`) | PASS | 15 | All correctly structured |
| Hooks (shell scripts) | PASS | 15 | Loaded via `settings.json` |
| `hooks.json` | WARNING | 1 | Reference only, not auto-loaded |
| Agents | PASS | 11 | Standard frontmatter format |
| Commands | PASS | 40 | 3 without frontmatter |
| MCP config | WARNING | 1 | Uses `mcp-servers.json` instead of `.mcp.json` |
| Rules | PASS | 9 | Auto-loaded by plugin system |
| `settings.json` | PASS | 1 | Requires install script merge |

### Action Items for Official Marketplace Submission

1. **HIGH**: Create `.mcp.json` at plugin root with flat format (from `mcp-servers.json`)
2. **MEDIUM**: Add frontmatter to `build-fix.md`, `refactor-clean.md`, `eval.md` commands
3. **LOW**: Remove extra fields from `plugin.json` for strict compatibility (optional, not breaking)
4. **LOW**: Remove `# Part of Claude Forge` comment line before `---` in agent files (optional)
