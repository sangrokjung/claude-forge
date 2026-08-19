---
name: relay
description: Session relay — compresses what's been done so far (writes a one-liner for /compact) and generates a "next task" prompt (a baton) for the user to hand off. Use on requests like "relay / hand off / next session / continue after compact / baton / handoff / clean up context and continue next task." Does not run /compact itself (a skill cannot do that) — it produces the one-liner the user pastes in.
allowed-tools: Bash(bash:*), Bash(git:*), Bash(date:*), Bash(hostname:*), Bash(uname:*), Read, Write, Glob, Grep, AskUserQuestion
disable-model-invocation: true
---

# relay — session relay (compact + next-task baton)

> Think of a relay race: the runner hands off the baton before stopping. Before context fills up, this
> skill produces two things: ① a one-line `/compact` command that compresses everything so far, and
> ② a handoff document (a "baton") that lets the next session start running immediately on the next task.

**When**: context is 70%+ used, work is about to be interrupted, or the user asks to "relay / hand off / next session / baton / handoff."

**Important (invariant)**: this skill **never runs `/compact` directly** (a skill cannot execute `/compact`).
It only produces **the one-liner the user pastes in**.

Let `$SKILL` be the absolute path of the directory containing this SKILL.md. Scripts live in `$SKILL/scripts/`.

## Flow

### 0) Parse arguments
From `$ARGUMENTS`:
- First positional argument = **next task (NEXT_TASK)**.
- Flags: `--new-session` (for a brand-new session — instructs the user to paste the whole baton), `--no-ask` (skip the clarifying question), `--quick` (skip prose, skeleton only), `--copy` (opt-in clipboard copy — off by default, see §6).

### 1) Collect state
Run `bash "$SKILL/scripts/relay-collect.sh"` → capture one JSON object. (facts about git/plan/session-summary/tasks/artifacts)
This JSON is the source of truth for every "fact." **Do not retype it from memory — quote it verbatim.**

### 2) Confirm the next task
If NEXT_TASK is empty and `--no-ask` was not passed, ask **one** AskUserQuestion:
"What's the first thing to do next?" — options pulled from `plan.next_unchecked` / `session_summary.next_steps`
/ `tasks.items` in the collect JSON, plus "type it myself." Tag the answer `[from-user]`.

### 3) Write the `/compact` one-liner
`bash "$SKILL/scripts/relay-build-focus.sh" "<NEXT_TASK>" "<files>" "<decision>"`
- `<files>` = key files relevant to the next task (space/comma separated, optional).
- `<decision>` = one line capturing a key decision to preserve (optional).

### 4) Write the skeleton baton immediately (guarantees an artifact even at 95% context)
`bash "$SKILL/scripts/relay-write-baton.sh" "<NEXT_TASK>" <path-to-collect.json or -> "<focus line>"`
- Save the collect JSON to a file and pass its path, or pipe it via stdin with `-`.
- This step leaves a valid (skeleton) baton on disk **even without prose**.

### 5) Add prose (optional — skip if `--quick`)
Follow `references/next-prompt-spec.md` to write §2 (context needed) and §4 (repro pitfalls), plus §1's body.
- Apply the **relevance filter** (KEEP / one-line / DROP) based on the next task.
- Facts come **verbatim** from the collect JSON; inferences get tagged `[from-claude]`.
- Save the prose to a temporary markdown file (use the `---§4---` marker to separate §2/§4), then re-run
  write-baton **with the prose file as the 4th argument** to splice it in.
- **Copy/prose text should read like a relaxed expert**, not a stiff, over-formal tone.

### 6) Output (three items — (c) must always be a code block)

(a) absolute path of the baton
(b) preview of the next prompt — excerpt from §1 MISSION
(c) the `/compact` one-liner, output **as a single fenced code block, verbatim**

**Never write (c) inline.** A long inline line wraps in the terminal and becomes hard to select and copy. A code block keeps it as one selectable unit.

- **Do not put it on the clipboard by default.** The clipboard is a single, volatile slot — if the user copies
  anything else in the meantime, the line is gone, and whatever was on the clipboard before gets silently
  overwritten without consent. On-screen text stays in scrollback and can be copied again anytime.
- If clipboard is actually needed, opt in explicitly with `--copy`, which sets `RELAY_COPY=1` on the write-baton
  call in step 4. Even then, still emit the (c) code block.
- With `--new-session`, instead of (c), tell the user to **paste the entire baton into the new session** (path from (a)).

## CRITICAL guards

- **Skeleton first, prose later**: if context runs out at step 4, a valid baton still remains.
- **MISSION-first**: oriented toward "what to do next," not a "log of what was done." §1 comes first.
- **Facts stay verbatim**: pulled directly from the collect JSON. Never retype from memory.
- **Never runs `/compact` directly** — the skill only produces the one-liner.
- **Always emit absolute paths** (no relative paths, no unexpanded `~`).
- **Can finish with just the skeleton** if context is running low.

## Opt-in auto-restore (SessionStart:compact)

`hooks/post-compact-restore.sh` is wired to settings.json's SessionStart (matcher `"compact"`). Right after
`/compact`, this hook injects the pointer (the carryover left by write-baton) into the session **exactly once
(consume-once)**.
- When auto-restore fires, the next task, carryover, and baton path reappear in context right after compaction.
- If the hook doesn't fire (no pointer / expired / already consumed), it **degrades gracefully** to the (a) baton
  path above — just Read that path.

## References

- Baton 7-section template + relevance filter + prose format: `references/next-prompt-spec.md` (SSOT)
- Scripts: `scripts/relay-lib.sh`, `relay-collect.sh`, `relay-build-focus.sh`, `relay-write-baton.sh`
- Auto-restore hook: `hooks/post-compact-restore.sh`

## Dev dependency (optional)

`tests/relay.bats` uses [bats-core](https://github.com/bats-core/bats-core). It is **not required** to use the
skill — only to run the test suite locally (`bats tests/relay.bats` from `skills/relay/`). If `bats` isn't
installed, the scripts still work standalone; just skip the test run.
