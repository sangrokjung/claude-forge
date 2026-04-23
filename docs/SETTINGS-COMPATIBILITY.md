# settings.json Field Compatibility Audit

**Last verified:** 2026-04-23 against [code.claude.com/docs/en/settings](https://code.claude.com/docs/en/settings) (Tier 0).

claude-forge's `settings.json` includes several fields/env vars that are **not currently documented in the public Claude Code settings reference**. They work at runtime (Claude Code accepts them) but are not part of the published contract. This page tracks their status so we can react to spec changes.

## Verified (✓ in public spec)

| Field | Source |
|-------|--------|
| `$schema` | General JSON convention |
| `cleanupPeriodDays` | [settings.md](https://code.claude.com/docs/en/settings) |
| `disableSkillShellExecution` | settings.md |
| `enabledMcpjsonServers` | settings.md |
| `env` | settings.md |
| `hooks` | [hooks.md](https://code.claude.com/docs/en/hooks) |
| `permissions` | [permissions.md](https://code.claude.com/docs/en/permissions) |
| `statusLine` | settings.md |

## UNVERIFIED (⚠ not found in spec)

| Field | Current value | Status | Recommended action |
|-------|---------------|--------|--------------------|
| `tui` | `true` | Not in 2026-04-23 spec dump. Works at runtime. | Keep for now; audit at next Claude Code release. Could be undocumented internal or renamed. |
| `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` | `"1"` | `EXPERIMENTAL_` prefix = beta flag, not in public env var reference. | Required for `TeamCreate`/`SendMessage` tools. Keep while feature is beta; remove once promoted. |
| `env.ENABLE_TOOL_SEARCH` | `"auto:5"` | Not in public env var reference. | Controls deferred-tool loading behavior. Keep; treat as internal tuning knob. |

## Hook timeout unit (verified 2026-04-23)

Public spec is explicit: `timeout` on hook handler objects is **in SECONDS** (not milliseconds):

> "Seconds before canceling. Defaults: 600 for command, 30 for prompt, 60 for agent."

SessionEnd has its own override rule: default budget 1.5 s, auto-raised up to 60 s based on declared per-hook timeouts; explicit override via `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` (in **milliseconds**, exception to the rule because env vars use ms convention).

claude-forge v3.0.0 (prior to this audit) used `"timeout": 5000`/`10000` values assuming milliseconds — those were effectively **5000 s / 10000 s** (83–166 min) to Claude Code. Corrected to `5`/`10` in v3.0.1. See commit history on the `chore/mcp-hook-cleanup` branch.

## How to re-run the audit

```bash
# Download current settings docs
curl -sL "https://code.claude.com/docs/en/settings" > /tmp/cc-settings.html

# Check each field is mentioned
for f in tui disableSkillShellExecution enabledMcpjsonServers; do
  echo -n "$f: "; grep -c "$f" /tmp/cc-settings.html
done
```

Any field with count `0` joins the UNVERIFIED table above. Any UNVERIFIED field that gets count `≥ 1` graduates to Verified.

## Rationale

Keeping undocumented-but-working fields is a trade-off. Removing them breaks features users depend on (team tools, deferred-tool tuning). Keeping them without a record means we won't notice when Claude Code's release notes silently rename or remove them. This audit is the middle ground: fields stay, but their out-of-spec status is public and testable.
