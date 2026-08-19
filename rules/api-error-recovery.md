---
name: api-error-recovery
load: conditional
audience: team
sensitivity: L1
category: reliability
critical: true
description: Unattended resume after a retryable API error — verdicts, resume paths, caps, kill switch
paths:
  - "**/api-error-auto-resume.sh"
  - "**/api-error-resume-runner.sh"
---

# API Error Recovery (unattended resume)

> Analogy: the caretaker who waits two minutes after a blackout, flips the breaker back
> on, and says "carry on where you left off". Unpaid bills and lost keys are left alone,
> and the breaker is never flipped more than a few times in a row.

Claude Code retries a 529 on its own and then gives up, leaving the session parked until a
person comes back. These two files pick it up from there.

| Piece | Path | Role |
|---|---|---|
| StopFailure hook | `hooks/api-error-auto-resume.sh` | Classify the failure, apply guards, detach-spawn the runner |
| Delayed runner | `scripts/api-error-resume-runner.sh` | Wait, then resume — dead / tmux / takeover paths |
| Wiring | `settings.json` → `hooks.StopFailure` (timeout 8 s) | The only place hooks are registered |
| Log | `~/.claude/logs/api-error-auto-resume.log` | Verdicts and outcomes, rotated at 1 MB |
| State | `~/.claude/cache/auto-resume/{counts,locks,runs,running,streak}` | Caps, locks, run logs |

## When it fires

`StopFailure` fires when a session ends abnormally, after Claude Code's built-in retries
are exhausted. The hook never blocks — `StopFailure` output cannot steer control flow — so
all real work happens in the detached runner.

## RETRY vs SKIP

The hook writes one verdict word per event to the log. These words are its contract; the
regression suite (`scripts/tests/test_auto_resume_classify.sh`) asserts them.

| Verdict | Meaning |
|---|---|
| `RETRY` | Resume scheduled, runner spawned |
| `SKIP` | Classified as not worth resuming |
| `CAP` | Per-session resume cap already reached |
| `DUP` | A runner for this session is already waiting (dropped without spending a cap slot) |
| `ERROR` | Runner missing or not executable — nothing scheduled |

| Classified `RETRY` | Classified `SKIP` |
|---|---|
| `error_type` / `stop_reason` in `overloaded`, `internal_error`, `api_error`, `server_error`, `connection_error`, `timeout`, `network_error` | `billing_error`, `authentication_failed`, `context_window_exceeded`, `invalid_request`, `permission_error` |
| Transcript `api_error` with HTTP 408, 500, 502, 503, 504, 522, 524, 529, or `isNetworkDown` | Transcript `api_error` with any other status |
| `Response stalled mid-stream` in the payload or transcript, whatever shape the error field has | A plain HTTP 429 with no server-side phrase — assumed to be your own usage limit |
| A rate limit the server marks as its own: `not your usage limit`, `temporarily limiting requests` | Anything inconclusive, and any payload with no session id |

Classification reads the stdin payload first and falls back to the last 256 KB of the
transcript (newest 200 records). It never greps the raw file for a status code — base64
payloads produce false positives.

**`stop_reason` wins over `error_type`, and shadows it when it matches nothing.** The
classifier evaluates `stop_reason or error_type` as a single value, so a payload carrying
both, such as `{"stop_reason":"error","error_type":"overloaded"}`, is judged on the literal
string `error`, matches neither the retryable nor the fatal set, and comes out `SKIP
(inconclusive)` — the `overloaded` is never consulted. This is the most surprising
behaviour in the classifier and the reason a plausible-looking fixture can assert the wrong
verdict. If you are writing a test or reading a puzzling `inconclusive` verdict, check
`stop_reason` first. Note that the transcript fallback still runs for such a payload, so a
transcript with a real `api_error` record recovers the RETRY.

`Retry in Ns` (also `Nm Ms`) is parsed out of the error text and handed to the runner,
which waits `max(DELAY, retry_in + RETRY_BUFFER)`, clamped to `MAX_DELAY`, plus up to 30 s
of jitter. Claude Code gets its own recovery window before we intervene, so "2 minutes" is
a floor, not a promise.

## Resume paths

The runner picks a path from the state of the original session process.

| State | What happens |
|---|---|
| Process gone (headless `-p` run, or the session exited) | `claude --resume <session_id> -p "<continue>"` — appends to the same transcript, killed by a watchdog after `MAX_RUNTIME` |
| Alive in a tmux pane | `tmux send-keys` types the instruction into the live REPL |
| Alive outside tmux (an ordinary terminal tab) | **Takeover**: end the original process gracefully (SIGTERM → 10 s → SIGKILL), then headless-resume the same session id |

**tmux injection has three safety gates**: skip if the pane is in copy-mode (capture would
read scrollback, not the live screen); skip if a permission dialog or menu is on screen (a
stray Enter would approve it); and re-capture right before Enter, withholding it if a
dialog appeared in between.

**Takeover only proceeds on a two-factor idle check.** The newest meaningful transcript
record must still be the API error and be at least `IDLE_MIN_AGE` seconds old, *and* two
CPU samples of the process must both be low. If the session looks like it is working or
has recovered on its own, the takeover is cancelled — the safety property is "it does not
arm", not "you can turn it off".

**The resume prompt carries a no-outward-actions guard.** A resumed headless session
inherits your `settings.json` permissions, and no interactive approval can be attributed to
it, so the default prompt forbids sending email or messages, merging PRs, deploying,
deleting data, and payments, and tells it to stop just before any such step and report.
If you replace it with `CLAUDE_AUTO_RESUME_PROMPT`, that guard is now your responsibility.

## Caps

A platform-wide outage makes every open session fire `StopFailure` at once, so resuming is
deduplicated much harder than a notification would be.

| Cap | Where | Behaviour |
|---|---|---|
| Per-session, 3 per rolling 6 h | hook | Counter under `counts/`, incremented by the runner once it holds the lock, so a duplicate fire cannot spend two slots |
| Progress-aware reset | hook | If the session actually moved forward after the last resume, the counter is zeroed — so the cap means "3 resumes in a row that achieved nothing", and an overnight run that keeps recovering is never cut off |
| Per-session lock | runner | `mkdir` is atomic; a lock older than `DELAY×3 + MAX_RUNTIME + 600 s` is reclaimed by an atomic `mv`, so exactly one racer wins |
| Global stagger | runner | `hook_cooldown "api-auto-resume-spawn" 20` (from `libs/hook-guard.sh`, sourced only if present); one resume per round, and after 30 rounds it gives up rather than join a stampede |
| Concurrency | runner | At most `MAX_CONCURRENT` runners alive at once |
| Hourly / daily totals | runner | `MAX_HOURLY` / `MAX_DAILY` resumes across all sessions, from `global.ledger` |
| No-progress streak | runner | The runner keeps its own ledger (the hook's reset can mistake a resume's own footprint for progress). After `NOPROGRESS_MAX` resumes that produced no non-error assistant turn, it writes the DISABLED file and stops everything |
| 429 refusal | runner | If the last API error in the transcript is a 429 or usage limit, it stops — rechecked after the wait, because the situation can change |

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `CLAUDE_AUTO_RESUME_DISABLED=1` | off | Kill switch (see below) |
| `CLAUDE_AUTO_RESUME_DELAY` | 120 | Seconds to wait before resuming |
| `CLAUDE_AUTO_RESUME_MAX_RETRIES` | 3 | Per-session resumes per 6 h |
| `CLAUDE_AUTO_RESUME_RETRY_RATELIMIT=1` | off | Also retry a plain `rate_limit` — off by default so a resume cannot burn down your own usage limit |
| `CLAUDE_AUTO_RESUME_RETRY_429=1` | off | Let the runner proceed even when the last error was a 429. Not recommended |
| `CLAUDE_AUTO_RESUME_DRY_RUN=1` | off | Runner logs the resume it would run and resumes nothing. It still waits first — see below |
| `CLAUDE_AUTO_RESUME_SELFTEST=1` | off | Runner prints its guard state and exits immediately. No lock, no wait, no resume |
| `CLAUDE_AUTO_RESUME_PROMPT` | built-in | Replaces the resume instruction — including its no-outward-actions guard |
| `CLAUDE_AUTO_RESUME_PERMISSION_MODE` | unset | Passed to `claude --permission-mode` on resume |
| `CLAUDE_AUTO_RESUME_MAX_RUNTIME` | 7200 | Watchdog ceiling for a headless resume, in seconds |
| `CLAUDE_AUTO_RESUME_TAKEOVER` | 1 | `0` reverts to the old behaviour: leave non-tmux sessions alone |
| `CLAUDE_AUTO_RESUME_RETRY_BUFFER` | 30 | Extra seconds after the server's `Retry in Ns` |
| `CLAUDE_AUTO_RESUME_MAX_DELAY` | 900 | Ceiling on the dynamic wait |
| `CLAUDE_AUTO_RESUME_IDLE_MIN_AGE` | 45 | Seconds a session must have been stuck before takeover may arm |
| `CLAUDE_AUTO_RESUME_MAX_CONCURRENT` | 6 | Runners alive at once |
| `CLAUDE_AUTO_RESUME_HOURLY_MAX` | 24 | Resumes per hour, all sessions |
| `CLAUDE_AUTO_RESUME_DAILY_MAX` | 80 | Resumes per 24 h, all sessions |
| `CLAUDE_AUTO_RESUME_NOPROGRESS_MAX` | 2 | Fruitless resumes in a row before self-disable |
| `CLAUDE_AUTO_RESUME_STRIP_API_KEY=1` | off | Unset `ANTHROPIC_API_KEY` / `ANTHROPIC_AUTH_TOKEN` for the resumed process. Leave it off if you authenticate with an API key; turn it on if your interactive sessions log in some other way and you do not want resumes billed to a stray key |
| `FORGE_NOTIFY_CMD` | unset | Optional notifier — see below |

### Dry run is not a fast smoke test

`CLAUDE_AUTO_RESUME_DRY_RUN=1` suppresses the resume itself, not the wait in front of it.
The runner still takes the lock, increments the cap counter, sleeps `EFF_DELAY + jitter`
(120 s by default, up to `MAX_DELAY` + 30 s, so roughly 15 minutes in the worst case) and
queues for a stagger slot before it logs the resume it would have run. That is deliberate:
a dry run exercises the real timing path. It is a poor fit for "did I break the script".

For an instant check, use the self test, which evaluates every guard and exits without
taking a lock, waiting, or resuming:

```bash
CLAUDE_AUTO_RESUME_SELFTEST=1 ~/.claude/scripts/api-error-resume-runner.sh <session-id> <cwd>
# SELFTEST-OK: 429=no-transcript concurrent=0/6 hourly=0/24 daily=0/80 noprogress_max=2
```

If a cap is already tripped the self test exits at that cap instead of printing the line,
and the reason lands in the log as the matching `GUARD-*` entry.

To shorten a real dry run instead, set `CLAUDE_AUTO_RESUME_DELAY=0` (jitter still adds up
to 30 s). Classification is covered separately by
`scripts/tests/test_auto_resume_classify.sh`, which runs in seconds.

### Notifications

The runner calls `notify "<title>" "<message>"` when it self-disables and after each
headless resume. With `FORGE_NOTIFY_CMD` unset that is a silent no-op; set it to a single
executable that takes those two arguments:

```bash
# ~/bin/forge-notify  (chmod +x)
#!/bin/bash
curl -fsS -m 5 -X POST "$MY_WEBHOOK_URL" \
  -H 'Content-Type: application/json' \
  --data "$(python3 -c 'import json,sys; print(json.dumps({"title":sys.argv[1],"text":sys.argv[2]}))' "$1" "$2")" >/dev/null
```

```bash
export FORGE_NOTIFY_CMD="$HOME/bin/forge-notify"
```

It must be one executable path, not a command line — arguments belong inside that script,
so nothing here word-splits or evaluates text that came from an error message.

## Kill switch

```bash
touch ~/.claude/cache/auto-resume/DISABLED   # applies to every session at once
rm ~/.claude/cache/auto-resume/DISABLED      # re-enable
```

`CLAUDE_AUTO_RESUME_DISABLED=1` does the same for one environment. Both are checked by the
hook before it does anything, and again by the runner after its wait, so a runner already
queued will stand down instead of resuming. To keep everything except takeover, set
`CLAUDE_AUTO_RESUME_TAKEOVER=0`.

For long unattended runs, tmux is the better host: injection continues the live session
without killing the TUI, whereas a takeover replaces it with a headless run (the work and
transcript survive; output moves to `cache/auto-resume/runs/*.log`).

## Platform

Developed and tested on macOS (bash 3.2, BSD `ps`, `stat -f`). Portability notes:

- `stat` is wrapped in a helper that tries BSD `-f` then GNU `-c`, and validates the
  result. Without it, the mtime reads would silently return 0 on Linux and both the cap
  window and the stale-lock threshold would stop working.
- The `ps` flags used (`-o ppid=`, `-o command=`, `-o tty=`, `-o %cpu=`) exist on Linux
  too. The tmux lookup builds `/dev/$tty` from `ps -o tty=`, which is `ttys00N` on macOS
  and `pts/N` on Linux — both resolve.
- **Not verified on Linux or WSL.** The failure mode of an unverified `ps`/`stat` is a
  resume that does not happen, not a wrong process being killed, since takeover requires a
  positive claude-process identity check on the PID. Run
  `bash scripts/tests/test_auto_resume_classify.sh` and one
  `CLAUDE_AUTO_RESUME_SELFTEST=1 scripts/api-error-resume-runner.sh <id> <cwd>` before
  trusting it on a new platform.

## Not included

This is a distribution of an internally-run tool; two things were deliberately left out.

- **No machine-load gate.** The internal build queued a resume behind a load/memory gate so
  it could not re-ignite an already saturated machine. That queue is not part of this
  repo, so the runner proceeds directly and logs `load gate not configured — proceeding`.
  If you run many sessions on one host, put your own gate in front of `headless_resume`.
- **No account-rotation signals.** Phrases like "all accounts exhausted" come from
  multi-account proxy pools and are not recognised here, so such a 429 lands on the
  conservative `SKIP`.
