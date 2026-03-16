# Claude Forge — Plugin Distribution Guide

## How Users Install Claude Forge

### Method 1: Plugin Marketplace (Recommended)

```bash
# Step 1: Add Claude Forge as a marketplace
/plugin marketplace add sangrokjung/claude-forge

# Step 2: Install the plugin
/plugin install claude-forge@claude-forge

# Update to latest version
/plugin marketplace update claude-forge
```

### Method 2: Direct GitHub Install

```bash
claude plugin install github:sangrokjung/claude-forge
```

### Method 3: Git Clone (for customization)

```bash
git clone --recurse-submodules https://github.com/sangrokjung/claude-forge.git
cd claude-forge && ./install.sh
```

---

## Submitting to Anthropic Official Marketplace

The official Anthropic marketplace (`claude-plugins-official`) is auto-available in Claude Code. Getting listed here gives maximum discoverability.

### Submission Methods

1. **In-app submission**: `/plugin` → Marketplaces → Submit
2. **Console**: [platform.claude.com/plugins/submit](https://platform.claude.com/plugins/submit)
3. **Claude.ai**: [claude.ai/settings/plugins/submit](https://claude.ai/settings/plugins/submit)

### Requirements

| Requirement | Claude Forge Status |
|-------------|:-------------------:|
| `plugin.json` with `name` field | Done |
| `version` field (semver) | Done (2.2.0) |
| `description` field | Done |
| `author` with name/url | Done |
| `repository` URL | Done |
| `license` (SPDX) | Done (MIT) |
| `keywords` for searchability | Done (9 keywords) |
| Working plugin structure | Done |
| README with installation docs | Done |

### Review Process

- Anthropic performs **automated review** on all submissions
- Plugins meeting quality/security standards get listed
- **"Anthropic Verified" badge**: Additional manual review from Anthropic's team for quality and safety
- External plugins must demonstrate:
  - No malicious code
  - Proper security practices
  - Clear documentation
  - Functional plugin structure

### Official Marketplace Repo

- GitHub: [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official)
- Contains curated plugins across categories: Code Intelligence, External Integrations, Development Workflows, Output Styles

---

## Plugin Structure Validation

Claude Forge's structure is **fully compatible** with the Claude Code plugin system:

```
claude-forge/                    ✅ Status
├── .claude-plugin/
│   ├── plugin.json              ✅ Full schema (name, version, author, etc.)
│   └── marketplace.json         ✅ Self-hosted marketplace catalog
├── agents/     (11 files)       ✅ Standard .md format
├── commands/   (40 files)       ✅ Standard .md format
├── skills/     (15 dirs)        ✅ All have SKILL.md
├── hooks/
│   └── hooks.json               ✅ 7 event types, compatible format
├── rules/      (9 files)        ✅ Standard .md format
├── scripts/                     ✅ Utility scripts
├── settings.json                ✅ Plugin settings support
└── mcp-servers.json             ✅ Referenced in plugin.json
```

### Verified Compatibility

- **Skills**: All 15 directories contain `SKILL.md` (required format)
- **Hooks**: `hooks.json` uses standard event types (PreToolUse, PostToolUse, SessionStart, Stop, etc.)
- **Agents**: Standard markdown format (frontmatter optional for agents)
- **Commands**: Standard markdown format with name/description headers
- **MCP Servers**: Referenced via `mcpServers` field in plugin.json
