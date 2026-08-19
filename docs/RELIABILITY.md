# Reliability pack (S1–S5)

> Five small, independent pieces that keep a long unattended session alive and honest: a
> shared guard library other hooks build on, an opt-in secret-commit blocker, unattended
> resume after an API outage, a handoff mechanism that survives context compaction, and two
> hooks that catch a session going in circles or shipping a syntax error. None of them talk
> to each other directly — each is off by one env var or file, and none is required for the
> other four to work.

Read this as a wiring map. For the full behavioral contract of any one piece, follow the
"Detail" link in its section — those documents are the source of truth; this page is the
index and the disable/enable switch reference.

## At a glance

| # | Component | Event(s) | Files | Kill switch |
|---|---|---|---|---|
| S1 | Shared hook guard (`libs/hook-guard.sh`) | n/a — a library other hooks `source` | `libs/hook-guard.sh` | Remove the sourcing line from the hook that uses it |
| S2 | Pre-commit secret guard | git `pre-commit` (not a Claude Code hook) | `scripts/install-precommit.sh` | `rm .git/hooks/pre-commit` in the target repo |
| S3 | API-error auto-resume | `StopFailure` | `hooks/api-error-auto-resume.sh`, `scripts/api-error-resume-runner.sh` | `touch ~/.claude/cache/auto-resume/DISABLED` or `CLAUDE_AUTO_RESUME_DISABLED=1` |
| S4 | Session relay + pre-compact snapshot | `PreCompact`, `SessionStart` (matcher `compact`) | `skills/relay/`, `hooks/pre-compact-snapshot.sh`, `hooks/post-compact-restore.sh` | Snapshot/restore hooks: deregister from `settings.json`. `relay` skill itself has no on/off switch — it only runs when invoked |
| S5 | Doom-loop detection + edit-time verify | `PostToolUse` (matcher `Edit\|Write`, and the unmatched group) | `hooks/loop-detection.sh`, `hooks/auto-verify-fix.sh` | Deregister from `settings.json`, or delete the `/tmp/claude-loop-detect-*.jsonl` state file to reset counts |

All five ship registered in `settings.json` except S2, which is a separate opt-in installer
you run against your own project's `.git/hooks/` — see its section below.

## Platform matrix

Everything in this pack was developed and tested on **macOS** (bash 3.2, BSD `ps`/`stat`).
Linux/WSL portability was addressed at the source level (portable `stat` helpers, `ps`
flags that exist on both platforms) but **not exercised on a real Linux or WSL host** during
this release. Stated honestly, per component:

| Component | macOS | Linux / WSL |
|---|:---:|:---:|
| S1 hook-guard | Verified (`scripts/tests/test_hook_guard.sh`, 8/8) | Should work — pure POSIX `mkdir`/mtime, no BSD-specific flags |
| S2 secret guard | Verified (`scripts/tests/test_precommit_guard.sh`, 18/18) | Should work — same reasoning, plus CI runs `ubuntu-latest` for the installer job |
| S3 auto-resume, headless-resume path | Verified (`scripts/tests/test_auto_resume_classify.sh`, 23/23; live dry-run) | `stat` is portable-wrapped and validated; `ps` flags exist on Linux. **Not run on Linux.** Failure mode of a wrong guess: a resume that silently doesn't happen, not a wrong process being signaled |
| S3 auto-resume, **takeover** path (kill + headless-resume a live non-tmux session) | Code-reviewed, dry-run branches exercised | **Never executed on any platform** in this release — see the warning below |
| S3 auto-resume, **tmux injection** path | Code-reviewed | **Never executed on any platform** in this release |
| S4 relay + pre-compact/post-compact | Verified (`bats skills/relay/tests/relay.bats`, 22/22) | Should work — no BSD-specific calls in the shipped scripts |
| S5 loop-detection + auto-verify-fix | Verified (functional smoke: 5x/10x edit thresholds, syntax-error detection) | Should work — no BSD-specific calls |

**Read the takeover/tmux row twice before relying on it.** The safety mitigations (positive
PID-identity check before any signal, two-factor idle check, cancel-on-any-progress, one env
var to disable) were verified by code review and their dry-run branches, not by triggering a
real outage against a live session and confirming the right process died. If you turn this
on for an unattended long-running job, watch the first few resumes.

## S1 — shared hook guard library

**What it does.** A tiny library two other pieces in this pack (and any hook you write)
`source` for two primitives: `hook_cooldown <name> <seconds>` (suppress repeat firings
within a window — the "cooldown notice at a meeting room door") and `hook_token_valid
<token>` (reject empty values and known placeholder strings like `YOUR_WEBHOOK_TOKEN`).

**Event.** None directly — it is a library, not a registered hook. It only runs when
something sources it.

**How to disable.** There is nothing to disable at the library level. If a specific hook's
use of the cooldown is unwanted, remove that hook's `source` line (every consumer sources it
as `[ -r ~/.claude/libs/hook-guard.sh ] && source ~/.claude/libs/hook-guard.sh` — guarded, so
a missing file degrades to a no-op rather than an error).

**Env vars.**

| Variable | Default | Meaning |
|---|---|---|
| `HOOK_GUARD_STATE_DIR` | `~/.claude/cache/hook-guard` | Where cooldown timestamps live, one file per `<name>` |

**Test.** `bash scripts/tests/test_hook_guard.sh` (8 cases).

## S2 — pre-commit secret guard

**What it does.** A git `pre-commit` hook that blocks a commit containing a shape that looks
like a live credential (`sk-...`, `ghp_...`, AWS `AKIA...`, Supabase `sbp_...`, and more),
staged `.env` files, and unusually large files. It is a **separate installer you run against
whichever git repo you want protected** — it does not touch this repo's own `.git/hooks/`
and is not wired into `settings.json`, because it protects your project's commits, not a
Claude Code session.

**Event.** Git's own `pre-commit`, not a Claude Code lifecycle event.

**Install (opt-in — nothing runs until you do this).**

```bash
bash scripts/install-precommit.sh              # installs into the repo containing $PWD
bash scripts/install-precommit.sh --all ~/code  # installs into every git repo under a tree (maxdepth 3)
```

The installer is idempotent: re-running it detects an already-installed guard by version
signature and skips, backing up any pre-existing `.git/hooks/pre-commit` to `.bak` the first
time it overwrites one.

**How to disable.**

```bash
rm .git/hooks/pre-commit          # remove from one repo
# or, one-time bypass for a single commit:
git commit --no-verify
```

**Env vars.** None — the guard reads only the staged diff.

**Test.** `bash scripts/tests/test_precommit_guard.sh` (18 cases). See
[`docs/PLUGIN-VS-INSTALL-SH.md`](PLUGIN-VS-INSTALL-SH.md) for how this fits alongside the
plugin-install and `install.sh` paths.

## S3 — API-error auto-resume

**What it does.** When a session ends abnormally after Claude Code's own retries are
exhausted, this classifies the failure and — if it looks like a transient server-side
problem rather than a billing/auth/context-limit/your-own-rate-limit failure — waits, then
resumes the session unattended. Full behavioral contract, the RETRY/SKIP/CAP/DUP/ERROR
verdict table, resume-path selection (headless / tmux / takeover), every safety cap, and the
complete environment-variable reference live in **[`rules/api-error-recovery.md`](../rules/api-error-recovery.md)**
— this section is the short version.

**Event.** `StopFailure` (timeout 8 s — the hook only classifies and detach-spawns; all real
work happens in the detached runner, since `StopFailure` output cannot steer control flow).

**How to disable.**

```bash
touch ~/.claude/cache/auto-resume/DISABLED   # applies to every session on this machine
rm ~/.claude/cache/auto-resume/DISABLED      # re-enable
# or, for one shell/session only:
export CLAUDE_AUTO_RESUME_DISABLED=1
```

To keep resume for headless/tmux sessions but never take over a live interactive terminal:

```bash
export CLAUDE_AUTO_RESUME_TAKEOVER=0
```

**Env vars (selected — full table in the rule doc).**

| Variable | Default | Meaning |
|---|---|---|
| `CLAUDE_AUTO_RESUME_DISABLED=1` | off | Kill switch for this shell |
| `CLAUDE_AUTO_RESUME_DELAY` | 120 | Seconds to wait before resuming |
| `CLAUDE_AUTO_RESUME_MAX_RETRIES` | 3 | Per-session resumes per rolling 6 h |
| `CLAUDE_AUTO_RESUME_TAKEOVER` | 1 | `0` disables killing and headless-resuming a live non-tmux session |
| `CLAUDE_AUTO_RESUME_DRY_RUN=1` | off | Waits and locks for real, logs the resume it would run, resumes nothing |
| `CLAUDE_AUTO_RESUME_SELFTEST=1` | off | Prints guard state and exits instantly — no lock, no wait, no resume |
| `CLAUDE_AUTO_RESUME_PROMPT` | built-in | Replaces the resume instruction, **including** its no-outward-actions guard — replace with care |
| `FORGE_NOTIFY_CMD` | unset | Path to one executable called as `notify_cmd "<title>" "<message>"` on self-disable and after each resume. See the contract below |

**`FORGE_NOTIFY_CMD` contract.** Unset, it is a silent no-op. Set it to a single executable
path (not a command line — arguments belong inside the script, since the title/message can
contain arbitrary text from an error payload and nothing here word-splits or evaluates it):

```bash
# ~/bin/forge-notify (chmod +x)
#!/bin/bash
curl -fsS -m 5 -X POST "$MY_WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  --data "$(python3 -c 'import json,sys; print(json.dumps({"title":sys.argv[1],"text":sys.argv[2]}))' "$1" "$2")" >/dev/null
```

```bash
export FORGE_NOTIFY_CMD="$HOME/bin/forge-notify"
```

**Test.** `bash scripts/tests/test_auto_resume_classify.sh` (23 cases, verdict classification
only — the resume paths themselves are covered by dry-run and self-test, not the regression
suite).

## S4 — session relay + pre-compact snapshot

**What it does.** Two things that cooperate but can be used independently:

1. The **`relay` skill** (`/relay`, or "hand off / next session / baton / continue after
   compact") writes a `/compact` one-liner and a "baton" markdown file — everything the next
   session needs to pick up immediately: the next task, key files, a decision to preserve,
   and facts pulled verbatim from git/plan/session-summary state. It never runs `/compact`
   itself (a skill cannot); it only produces the line you paste in.
2. **`hooks/pre-compact-snapshot.sh`** (`PreCompact`) and **`hooks/post-compact-restore.sh`**
   (`SessionStart`, matcher `compact`) are an *opt-in automatic* layer on top: right before a
   compaction, the snapshot hook records a pointer to the most recent baton; right after,
   the restore hook injects that pointer into the fresh session's context exactly once
   (consume-once — it will not fire twice for the same baton). If no pointer exists, is
   expired, or was already consumed, it degrades gracefully to nothing — you fall back to
   manually reading the baton path the skill printed.

**Events.** `PreCompact` (snapshot) and `SessionStart` with `matcher: "compact"` (restore).

**How to disable.** Remove both entries from `settings.json`'s `hooks.PreCompact` and
`hooks.SessionStart` arrays. The `relay` skill itself is invocation-only — it has no
standing process to disable, since nothing runs until you ask for it.

**Env vars.**

| Variable | Default | Meaning |
|---|---|---|
| `RELAY_TASKS_FILE` | unset | Optional path to a task list the collector reads into the baton's `tasks` section. Skipped silently if unset or unreadable |
| `RELAY_COPY=1` | off | Set by the skill's `--copy` flag — opts into also placing the `/compact` one-liner on the clipboard. Off by default because the clipboard is a single volatile slot; on-screen text in a code block stays in scrollback and can be copied any time |

**Test.** `bats skills/relay/tests/relay.bats` (22 cases — requires
[bats-core](https://github.com/bats-core/bats-core); the skill and both hooks work standalone
without it, the suite is dev-only).

**Detail.** [`skills/relay/SKILL.md`](../skills/relay/SKILL.md).

## S5 — doom-loop detection + edit-time verify

**What it does.** Two lightweight `PostToolUse` nudges, both fired on every `Edit`/`Write`:

1. **`loop-detection.sh`** counts how many times the current session has edited the same
   file. At 5 edits it surfaces a gentle nudge; at 10 it surfaces a stronger one with three
   concrete suggestions (step back, re-read the file, ask a clarifying question). Delivered
   as `hookSpecificOutput.additionalContext` JSON, so the message actually reaches the
   model — not a plain-stdout echo, which `PostToolUse` does not deliver.
2. **`auto-verify-fix.sh`** runs a lightweight syntax/type check (`.ts`/`.tsx`/`.js`/`.jsx`
   via the nearest `tsconfig.json`/`package.json`, `.py` via `py_compile`) immediately after
   an edit to one of those extensions, and surfaces fixable errors the same way — as
   `additionalContext`, not a blocking failure (`PostToolUse` cannot block).

**Event.** `PostToolUse`, matcher `Edit|Write` (`auto-verify-fix.sh`) and the unmatched
group (`loop-detection.sh` — it self-filters to `Edit`/`Write` inside the script, so both
effectively fire on the same tool calls).

**How to disable.** Remove the corresponding entry from `settings.json`'s
`hooks.PostToolUse` array. To reset `loop-detection.sh`'s per-file counters without
disabling it, delete its session-scoped state file:

```bash
rm /tmp/claude-loop-detect-*.jsonl
```

**Env vars.** None — both hooks are self-contained with fixed thresholds (5/10 edits for
loop-detection; the fixed extension allowlist above for auto-verify-fix) and no
configuration surface.

**Test.** `bash -n` on both scripts, plus functional smoke: 5x and 10x same-file edits
against `loop-detection.sh` confirm both threshold branches round-trip through the JSON
envelope, and a `.py` file with a deliberate syntax error confirms `auto-verify-fix.sh`
surfaces it.

## Why these are grouped together

Every other new capability in v4.0 (the adversarial verification loop, Korean prose
guardrails) changes *what gets written or reviewed*. This pack changes *what happens when
nothing is watching* — an API outage past midnight, a context window filling up mid-task, a
session stuck editing the same file five times in a row. None of the five talk to each
other; each has its own kill switch; and four of the five ship on by default because their
failure mode without you present is silence, not damage. Read the platform matrix above
before trusting the two paths that were never fired against a live outage.
