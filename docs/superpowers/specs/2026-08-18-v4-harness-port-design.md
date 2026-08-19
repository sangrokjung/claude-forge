# claude-forge v4.0 — Harness Port Design

Date: 2026-08-18
Status: DRAFT (pending maintainer approval)

## 1. Goal

Port nine battle-tested capability sets from the maintainer's internal Claude Code
harness into claude-forge, released as **v4.0.0** in a single drop. Selection was
deliberately strict: every set either (a) answers demand external users have already
demonstrated through their own PRs and issues on this repo, (b) is the adversarial
verification loop — the release flagship, or (c) serves the Korean-speaking Claude
Code community this project uniquely addresses with its trilingual docs.

A 74-candidate survey of the internal harness preceded this selection; 13 further
sets were consciously deferred (see §5).

## 2. What ships (9 sets)

### Pack 1 — Reliability & Safety

**S1. `hook-guard.sh` shared hook library** — `libs/hook-guard.sh`
Cooldown (multi-session notification-storm prevention), webhook token placeholder
guard, `$PYTHON3` resolution. Priority zero because `hooks/context-sync-suggest.sh`
already sources this file and claude-forge has never shipped it — for any user
without an unrelated copy at `~/.claude/libs/`, that hook depends on the optional
fallback added in v3.1.1. This closes the dependency properly.
*Acceptance: every shipped hook that sources the library runs green on a clean
`$HOME`; `install.sh`/`install.ps1` both place `libs/`; cooldown behaviour covered
by a shell test.*

**S2. Secret commit guard + regression suite** — `scripts/install-precommit.sh`,
`scripts/tests/test_precommit_guard.sh`
Pre-commit secret scanner (v9): prefix-key patterns, base64 catch-all with
hex/URL/ssh-pubkey false-positive filters, placeholder exclusion, PEM/PuTTY private
key block, .env block, large-file block. Ships with its 17-case bidirectional
regression suite, including the v7 SIGPIPE case where a real token was silently
passed. Installer adapted from "all repos under a base dir" to "current repo"
(+ `--all` option).
*Cuts: QJC catalog self-heal section (§4 of the internal hook) removed entirely.*
*Acceptance: regression suite 17/17 in CI; guard installs into a fresh repo and
blocks/passes the documented cases.*

**S3. API-error auto-resume** — `hooks/api-error-auto-resume.sh`,
`scripts/api-error-resume-runner.sh`, `rules/api-error-recovery.md`
StopFailure-triggered unattended session resume for retryable API errors
(overloaded / 5xx / server-side rate limits), with the mature guard stack:
per-session rolling cap, progress-aware cap reset, atomic locks, global stagger,
`Retry in Ns` parsing, dead/tmux/takeover resume paths.
*Cuts: Moshi notification → pluggable `FORGE_NOTIFY_CMD` env hook (no-op default);
TeamClaude proxy signals ("accounts exhausted") removed; qgate load-gate wait
removed; headless resume keeps the built-in "no outward actions" guard prompt.*
*Acceptance: dry-run mode exercises RETRY/SKIP classification on fixture payloads;
fork-bomb caps covered by tests; kill switch documented.*

**S4. Session relay (context-exhaustion handoff)** — `skills/relay/`,
`hooks/pre-compact-snapshot.sh`
Collects git/plan/session state into a baton document before compaction and
restores it automatically post-compact (consume-once). Complements the existing
`strategic-compact` skill (timing) with artifacts (content).
*Cuts: one `QJC_BASE`/TODAY.md reference in `relay-collect.sh`.*
*Acceptance: baton generated on a fixture repo; PostCompact restore path documented
and wired via `settings.json` example.*

**S5. Doom-loop detection + edit-time verify** — `hooks/loop-detection.sh`,
`hooks/auto-verify-fix.sh`
Warns when the session repeats near-identical failing actions; runs cheap
typecheck-level verification right after edits. Zero external dependencies.
*Acceptance: loop fixture triggers the warning; hooks are additionalContext-only
(non-blocking) per the notification-channel rules.*

### Pack 2 — Verification & Review Process

**S6. Adversarial verification set (flagship)** — `skills/review-loop/`,
`agents/adversarial-reviewer.md`, `agents/skeptical-auditor.md`,
`rules/adversarial-review.md`
The maker≠checker loop: every behavioural change is reviewed by a fresh-context
checker that did not write it, returning exactly APPROVE / REQUEST_CHANGES /
UNVERIFIED with reproduced evidence; the maker fixes and re-submits until APPROVE.
Lightweight protocol only — the internal deterministic gate (SHA pinning, seatbelt,
receipt CLI, hooks) is **not** ported; the state machine, fresh-identity rule,
verdict contract, and re-verification etiquette are.
Release-note material: in dogfooding on this very repo (2026-08-18), this process
caught three real defects the author missed — a parity guard that could not detect
the exact regression it existed to catch, a first-assignment-only AST check, and an
lxml ceiling that excluded the library's current major.
*Acceptance: loop documented end-to-end; agents carry read-only tool sets; worked
example included; verdict schema named `forge.review/v1`.*

**S7. Debugging escalation chain** — `agents/systematic-debugger.md`,
`agents/rca-debugger.md`, `agents/escalation-fixer.md`
reproduce→bisect→hypothesize→verify lane, escalating to root-cause analysis
(5-why/fishbone) and last-resort architectural fixing with an escalation log.
Merges external **PR #24** (systematic-debugging skill, @JYHTHEGREAT) as the
methodology layer and adds these agents as the execution lane, with credit.
*Cuts: `mcp__chrome__*` tool names remapped to the shipped chrome-devtools MCP
naming; superpowers skill references made optional.*
*Acceptance: agent frontmatter passes the existing schema CI; chain boundaries
(build-error-resolver vs systematic vs rca vs escalation) documented.*

**S8. Task-grade routing** — extends external **PR #23** (`/workflow-classify`,
@JYHTHEGREAT) rather than shipping a parallel rule
Adds the internal harness's contribution on top of the contributor's S/M/L/XL
classifier: per-grade documentation depth (none / micro-spec / spec+plan / full
SDD) and per-grade verification strength (targeted check → independent adversarial
lanes), with the "minimum L for auth/payment/PII/irreversible" escalation ladder.
*Acceptance: PR #23 merged with credit; one command, one doc; no duplicate
classifier ships.*

### Pack 3 — Korean Writing Quality

**S9. Korean quality set** — `rules/korean-writing-quality.md`,
`reference/ai-tell-taxonomy.md`, `hooks/emdash-slop-guard.sh` +
`scripts/emdash_slop_check.py`, `skills/humanize-korean/` (lite),
`skills/korean-character-count/`, `skills/korean-spell-check/`
Generation-time avoidance standard for translationese and AI-tell patterns in
Korean prose (10-class taxonomy with severity), deterministic em-dash
interjection guard, post-hoc humanize pass (lite: single-agent, no 5-persona
pipeline), plus the two small vendored utility skills.
*Cuts: QJC brand/voice clauses; L3 vendor-surface routing rewritten as a generic
"don't send sensitive text to third-party model surfaces" note; humanize strict
mode (5-agent) not ported.*
*Acceptance: emdash guard has fixture tests (body/heading/table-cell exemptions);
taxonomy doc standalone; skills pass the frontmatter CI.*

## 3. Common porting rules (applies to every set)

1. **Scrub**: no client names, internal hosts, Tailscale addresses, Supabase
   endpoints, or incident-log narrative tied to internal business.
2. **Pluggable notify**: any alert becomes `FORGE_NOTIFY_CMD` (env-injected
   command, silent no-op default). No Moshi/Discord/Telegram hardcoding.
3. **MCP remap**: `mcp__chrome__*` → the four shipped MCP servers' standard names.
4. **Platform matrix**: macOS-only mechanisms (launchctl, proc_pid_rusage) get an
   explicit platform note and a Linux fallback or graceful skip.
5. **No superpowers assumption**: `superpowers:*` skill references removed or
   marked optional.
6. **Ship what you reference** (the work-tracker-sync lesson, #6): every file a
   shipped component sources/execs must itself ship, or the reference must be
   guarded and documented as optional.
7. **Pass the new CI**: hooks manifest guard, installer parity (AST), commands/
   skills frontmatter validation — all added 2026-08-18 — plus updated inventory
   counts across plugin.json, marketplace.json, README×3, MIGRATION.

## 4. Release mechanics

- Branch `release/v4.0`; commits grouped per set (S1..S9) for reviewability.
- Per-pack independent adversarial review (fresh checker, isolated worktree), the
  same process being shipped as S6 — dogfooding is part of the release story.
- External PRs #23 and #24 are merged into the release branch first, with
  contributor credit preserved; S7/S8 build on top.
- Docs: README×3 feature sections, MIGRATION v3→v4, inventory counts, new
  `docs/RELIABILITY.md` (S1–S5 wiring guide) and `docs/VERIFICATION-LOOP.md` (S6).
- Version: 4.0.0 across plugin.json / marketplace.json (both slots) / docs, gated
  by the existing doc-version-sync CI.
- Install: `install.sh` + `install.ps1` updated in lockstep (parity CI enforces).

## 5. Non-goals (deferred to v4.1 backlog issues)

qgate load gate (full or lite), memory-hog-guard, notification-policy rule set,
context-percentage monitor, meta-improvement loop, memory policy/supersede,
goal-maker, a11y/performance reviewer pair, pull-main / worktree isolation /
push-before-ci git trio, dry-run preview, sprint-contract, karpathy-check,
QA 4-agent set. Each gets a backlog issue with its survey rationale so external
contributors can pick them up.

## 6. Risks

- **Auto-resume complexity (S3)**: largest genericization surface; mitigated by
  dry-run mode, fixture tests, and a kill switch. If review stalls it, it moves to
  v4.1 and v4.0 ships 8 sets — the release does not block on it.
- **Korean pack perception**: clearly framed in README as the Korean-community
  differentiator, not padding; English/Chinese READMEs describe it in one line.
- **Inventory drift**: counts change in 8+ places; doc-version-sync CI plus a
  final count-verification pass before tagging.
