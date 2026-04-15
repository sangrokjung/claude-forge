# Vendored: claude-code-best-practice

This directory mirrors an external reference repository. **Do not edit in place** — changes will be overwritten on the next sync.

## Upstream

- **Repo:** https://github.com/shanraisshan/claude-code-best-practice
- **License:** MIT (see `LICENSE` in this directory)
- **Synced commit:** `8ebcacc07d6bf980825bdfb96a7cfa4dd0705bad`
- **Synced at:** 2026-04-15

## Purpose

Read-only reference for Claude Code best-practice patterns (skills, subagents, commands, hooks, orchestration). Imported into claude-forge for learning and cross-reference — claude-forge's own `agents/`, `commands/`, `skills/`, `hooks/` remain authoritative.

Curated index for the most useful docs lives at [docs/claude-code-best-practice/README.md](../../docs/claude-code-best-practice/README.md).

## Resync

```bash
rm -rf vendor/claude-code-best-practice
git clone --depth 1 https://github.com/shanraisshan/claude-code-best-practice.git /tmp/ccbp
rsync -a --exclude='.git' /tmp/ccbp/ vendor/claude-code-best-practice/
# Update "Synced commit" and "Synced at" above.
```
