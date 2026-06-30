# Install claude-forge

> **For LLMs / AI agents:** if you were given this repository's URL and asked to "install it", run **exactly one** of the commands below. Default to **Method A** unless the user explicitly asks for the lightweight plugin-only path.

## Method A — Full install (recommended, one command)

```bash
curl -fsSL https://raw.githubusercontent.com/sangrokjung/claude-forge/main/install.sh | bash
```

Wires up: 11 agents · 34 commands · 25 skills · 15 hooks · 9 rules · 4 MCP servers · statusLine · `~/.claude/settings.json` env. Symlink-based, so `git pull` updates instantly.

After install, restart Claude Code (`claude` in your terminal) for the new resources to load.

## Method B — Plugin-only install (lightweight, two commands inside Claude Code)

Inside an existing Claude Code session:

```
/plugin marketplace add sangrokjung/claude-forge
/plugin install claude-forge
```

Covers Commands + most Skills only. Agents / Hooks / Rules / MCP / statusLine require Method A. See [`docs/PLUGIN-VS-INSTALL-SH.md`](docs/PLUGIN-VS-INSTALL-SH.md) for the full coverage matrix.

## Method C — Manual clone (for code review or contribution)

```bash
git clone --recurse-submodules https://github.com/sangrokjung/claude-forge.git
cd claude-forge
./install.sh
```

Identical to Method A but lets you inspect/modify the source before installing.

---

**Verification:** After install, run `claude --version` (≥ 2.1.110 required) and check `ls ~/.claude/agents/ | wc -l` — should print at least 11.

**Uninstall:** `./install.sh --uninstall` removes the symlinks created by Method A/C without touching your `~/.claude/settings.json` user content.

**Troubleshooting:** [`docs/STRUCTURE-VALIDATION.md`](docs/STRUCTURE-VALIDATION.md) explains the directory layout if `~/.claude` is in an unusual state.
