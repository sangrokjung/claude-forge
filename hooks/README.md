# claude-forge Hooks (v3.0)

> Claude Code harness hooks — opt-in handlers for 21 lifecycle events.
> Hooks fire inside the Claude Code runtime, read JSON from stdin, and gate behavior via exit codes.

## Event Catalog

Claude Code v3.0 exposes **21 hookable events** across 7 categories. Install only what you need.

| Category | Event | Trigger | Common Use | Example |
|----------|-------|---------|------------|---------|
| Session | `SessionStart` | New session boots / `--continue` resume | Inject context, warm caches, print banners | `context-sync-suggest.sh` |
| Session | `SessionEnd` | Clean session shutdown | Persist summary, sync TODAY.md | `work-tracker-stop.sh` |
| Turn | `UserPromptSubmit` | User sends a prompt | Track activity, pre-flight checks | `work-tracker-prompt.sh` |
| Turn | `Stop` | Assistant finishes a clean turn | Nudge session-wrap, commit suggest | `session-wrap-suggest.sh` |
| Turn | `StopFailure` | Session ends abnormally (crash, rate-limit) | Dump crash report, set recovery flag | `examples/stop-failure.sh.example` |
| Tool | `PreToolUse` | Before a tool runs | Guard destructive commands, rate-limit MCP | `remote-command-guard.sh` |
| Tool | `PostToolUse` | After a tool runs (success OR failure) | Filter output secrets, log usage | `output-secret-filter.sh` |
| Tool | `PostToolUseFailure` | Tool returns non-zero (failure only) | Escalate repeated failures, alert | `examples/post-tool-use-failure.sh.example` |
| Subagent | `SubagentStart` | Task tool spawns a subagent | Record subagent name + start time | `examples/subagent-start.sh.example` |
| Subagent | `SubagentStop` | Subagent finishes (success or failure) | Log duration, cost accounting | `examples/subagent-stop.sh.example` |
| Context | `PreCompact` | Before context compaction runs | Snapshot TODAY.md / plan.md | `examples/pre-compact.sh.example` |
| Context | `PostCompact` | After compaction completes | Persist summary for audit/relay | `examples/post-compact.sh.example` |
| System | `ConfigChange` | `settings.json` mutated | Revalidate schema, reload hooks | (custom) |
| System | `CwdChanged` | Working directory changes | Reset project context | (custom) |
| System | `FileChanged` | Claude edits a watched file | Kick linters / formatters | (custom) |
| System | `InstructionsLoaded` | CLAUDE.md / rules loaded | Audit rule sources | (custom) |
| System | `Notification` | User-facing notification emitted | Mirror to Discord/Slack | (custom) |
| System | `PermissionDenied` | A permission prompt was denied | Audit-log denials | (custom) |
| System | `TaskCreated` | Task tool creates a new task | Log assignment, notify team | `examples/task-created.sh.example` |
| System | `TaskCompleted` | Task marked completed | Close loop, emit metrics | `task-completed.sh` |
| Worktree | `WorktreeCreate` | New git worktree registered | Seed `.claude/` symlink, log | `examples/worktree-create.sh.example` |
| Worktree | `WorktreeRemove` | Worktree torn down | Block if unmerged, cleanup | `examples/worktree-remove.sh.example` |

## Hook Handler Types

Each hook entry specifies a `type`. v3.0 supports four:

| Type | Purpose | Notes |
|------|---------|-------|
| `command` | Run a shell script (most common) | Takes `command`, optional `timeout` (ms) |
| `http` | POST the payload to an HTTP endpoint | Takes `url`, `headers` — good for Zapier/webhooks |
| `llm-prompt` | Invoke a nested LLM with a preset prompt | Takes `prompt`, `model` — used for "auto-review" style checks |
| `mcp-tool` | Invoke an MCP tool directly | Takes `server`, `tool`, `arguments` |

## Matcher Schema

Hooks in the same event can be filtered by a `matcher` glob to narrow when they fire.

```json
{
  "PreToolUse": [
    {
      "matcher": "Bash",
      "hooks": [
        { "type": "command", "command": "~/.claude/hooks/remote-command-guard.sh", "timeout": 5000 }
      ]
    },
    {
      "matcher": "mcp__*",
      "hooks": [
        { "type": "command", "command": "~/.claude/hooks/rate-limiter.sh" }
      ]
    }
  ],
  "SubagentStop": [
    {
      "hooks": [
        { "type": "command", "command": "~/.claude/hooks/subagent-stop.sh" }
      ]
    }
  ]
}
```

Matcher semantics:
- Omit `matcher` to catch all invocations of that event.
- `matcher` accepts exact tool names (`Bash`, `Edit`) or globs (`mcp__*`, `Edit|Write`).
- Multiple matcher blocks in the same event are OR-ed.

## Security Notes

- **Exit codes** — `0` = success, `2` = blocking error (rejects the action), anything else = non-blocking warning logged to stderr.
- **Timeout** — Default 60 s. Set `timeout` (ms) to enforce per-hook budget; blocking hooks that run long will stall the session.
- **Input** — Hooks receive the full event payload on stdin as JSON. Parse defensively; never assume fields exist.
- **Secrets** — Never `echo $ANTHROPIC_API_KEY` or print env vars; PostToolUse secret filter may not cover stderr.
- **Side-effects** — Avoid network calls without rate-limit guards. Long-running hooks block the whole session.
- **Scripts** — Must be executable (`chmod +x`). Use absolute paths or `~/` expansion.

## Migration from v2.1

v2.1 shipped **5 events** and shared a flat handler list. v3.0 expands to **21 events** with opt-in per-event installation. Existing v2.1 hooks continue to work unchanged.

| v2.1 event | v3.0 replacement | Breaking? |
|------------|------------------|-----------|
| `SessionStart` | `SessionStart` | No |
| `UserPromptSubmit` | `UserPromptSubmit` | No |
| `PreToolUse` | `PreToolUse` | No |
| `PostToolUse` | `PostToolUse` + new `PostToolUseFailure` | No (additive) |
| `Stop` | `Stop` + new `StopFailure` | No (additive) |
| — | 16 new events (Subagent / Context / System / Worktree) | Opt-in |

Opt-in steps:
1. Copy the desired `examples/*.example` into `~/.claude/hooks/<name>.sh`.
2. `chmod +x ~/.claude/hooks/<name>.sh`.
3. Append a new entry to the corresponding event array in `~/.claude/settings.json`.
4. Restart your Claude Code session (or `claude --reload-settings` if available).

To disable a hook without deleting it, comment the entry out of `settings.json` or remove the `+x` bit.
