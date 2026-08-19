# claude-forge v4.0 Harness Port Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port nine battle-tested capability sets from the maintainer's internal harness into claude-forge and release as v4.0.0.

**Architecture:** Each set is one commit group on `release/v4.0`: read the internal source, cut the documented QJC bindings, place under the forge layout, verify with the repo's own CI checks reproduced locally, commit. External PRs #23/#24 merge first so S7/S8 build on top. Docs/version/inventory land last in one pass.

**Tech Stack:** bash (`/bin/bash`-pinned for hooks), python3 (stdlib only), Claude Code agent/skill/command markdown, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-18-v4-harness-port-design.md`

## Global Constraints

Copied from spec §3 — every task implicitly includes these:

1. Scrub: no client names, internal hosts, Tailscale addresses, Supabase endpoints, or internal incident narrative.
2. Pluggable notify: alerts go through `FORGE_NOTIFY_CMD` (env-injected command; silent no-op when unset). Never hardcode Moshi/Discord/Telegram.
3. MCP remap: `mcp__chrome__*` → `mcp__chrome-devtools__*`; `mcp__plugin_playwright_playwright__*` → `mcp__playwright__*`.
4. Platform: macOS-only mechanisms get a platform note and a Linux fallback or graceful skip.
5. No `superpowers:*` skill assumptions — remove or mark optional in prose.
6. Ship what you reference: every sourced/exec'd file ships, or the reference is guarded `[ -r ... ] && source ...` and documented optional.
7. Pass repo CI locally before each commit: `python3 -m json.tool settings.json`, frontmatter jobs (agents schema + commands/skills YAML), hooks-manifest guard (`! test -e hooks/hooks.json`), installer parity. Shell: `bash -n` on every touched `.sh`.
8. Shebang for all ported hooks/scripts: `#!/bin/bash` (NOT `/usr/bin/env bash` — homebrew bash 5.3.15 deadlocks on <64KB variable herestrings, measured 2026-08-18). Any regex scan in guards uses `GREP=/usr/bin/grep` with `command -v grep` fallback.
9. Source-of-truth paths (read-only inputs, never modified): `~/.claude/libs/`, `~/.claude/hooks/`, `~/.claude/scripts/`, `~/.claude/skills/`, `~/.claude/agents/`, `~/qjc-office/dotclaude/rules/`, `~/qjc-office/dotclaude/reference/`, `~/qjc-office/dotclaude/scripts/`.
10. All work on branch `release/v4.0` in `/Users/sangrok/qjc-office/claude-forge`.

---

### Task 1: Merge external PRs #23 and #24 into release/v4.0

**Files:**
- Create (via merge): `commands/workflow-classify.md` (PR #23, @JYHTHEGREAT)
- Create (via merge): `skills/systematic-debugging/SKILL.md`, `skills/systematic-debugging/references/external-research-guide.md`, `skills/systematic-debugging/references/root-cause-tracing.md` (PR #24, @JYHTHEGREAT)

**Interfaces:**
- Produces: `commands/workflow-classify.md` (Task 9 extends it), `skills/systematic-debugging/` (Task 8's agents reference it as the methodology layer).

- [ ] **Step 1: Fetch and merge both PR branches into release/v4.0, preserving authorship**

```bash
cd /Users/sangrok/qjc-office/claude-forge && git checkout release/v4.0
git fetch origin pull/23/head:pr-23 pull/24/head:pr-24
git merge --no-ff pr-23 -m "feat(commands): add /workflow-classify for S/M/L/XL task sizing (#23)

Merged from JYHTHEGREAT:feat/workflow-classify with credit. Task-grade
routing (v4.0 S8) extends this in a follow-up commit."
git merge --no-ff pr-24 -m "feat(skills): add systematic-debugging — 6-phase structured debugging (#24)

Merged from JYHTHEGREAT:feat/systematic-debugging with credit. The v4.0
debugging agent lane (S7) builds on this as its methodology layer."
```

If either merge conflicts: resolve favoring the PR's content for its own new files; if a conflict touches files outside the PR's list above, stop and report.

- [ ] **Step 2: Verify frontmatter passes the repo CI checks locally**

```bash
python3 - <<'EOF'
import re, yaml, pathlib, sys
bad = 0
for p in ['commands/workflow-classify.md', 'skills/systematic-debugging/SKILL.md']:
    t = pathlib.Path(p).read_text()
    m = re.match(r'^---\n(.*?)\n---\n', t, re.DOTALL)
    if not m: print(f"FAIL no frontmatter: {p}"); bad += 1; continue
    d = yaml.safe_load(m.group(1))
    h = d.get('argument-hint')
    if h is not None and not isinstance(h, str): print(f"FAIL argument-hint not str: {p}"); bad += 1
print("OK" if not bad else "FAILED"); sys.exit(bad)
EOF
```

Expected: `OK`. If FAIL: quote the offending `argument-hint` in double quotes (or single quotes if the value contains double quotes) and amend the merge commit.

- [ ] **Step 3: Comment on both PRs that they are merged into the release branch**

```bash
gh pr comment 23 --body "Merged into release/v4.0 for the v4.0 release — thank you. The v4.0 task-grade routing work extends your classifier with per-grade documentation depth and verification strength rather than shipping a parallel one. Credit preserved in the merge commit."
gh pr comment 24 --body "Merged into release/v4.0 for the v4.0 release — thank you. v4.0 adds a debugging agent lane (systematic-debugger → rca-debugger → escalation-fixer) that uses your skill as its methodology layer. Credit preserved in the merge commit."
```

(Do not close the PRs; GitHub closes them automatically when release/v4.0 merges to main.)

---

### Task 2: S1 — ship `libs/hook-guard.sh` and wire installers

**Files:**
- Create: `libs/hook-guard.sh` (from `~/.claude/libs/hook-guard.sh`, 59 lines, zero bindings — verbatim except header comment)
- Create: `scripts/tests/test_hook_guard.sh`
- Modify: `install.sh` (two `for` lists: line ~282 `for dir in agents rules commands scripts skills hooks ...` and verify list line ~575)
- Modify: `install.ps1` (`$directories` array line ~257, `$items` verify array line ~341)
- Modify: `hooks/context-sync-suggest.sh` (comment only: the optional-source note now points at the shipped copy)

**Interfaces:**
- Produces: `hook_cooldown <name> <seconds>` (returns 1 = suppressed), `hook_token_valid <token>` (returns 1 = placeholder/empty), `$PYTHON3` variable. Installed to `~/.claude/libs/hook-guard.sh`. Tasks 5 and 6 hooks may source it with the guarded pattern from Global Constraint 6.

- [ ] **Step 1: Write the failing test**

Create `scripts/tests/test_hook_guard.sh`:

```bash
#!/bin/bash
# hook-guard.sh regression: cooldown suppresses within window, token guard
# rejects placeholders. Run: bash scripts/tests/test_hook_guard.sh
set -uo pipefail
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/libs/hook-guard.sh"
[ -r "$LIB" ] || { echo "FAIL: libs/hook-guard.sh missing"; exit 1; }
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
no(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }

# isolated cooldown state dir
export HOOK_GUARD_STATE_DIR=$(mktemp -d)
# shellcheck source=/dev/null
HOOK_GUARD_SKIP_STDIN=1 source "$LIB"

hook_cooldown "t-$$" 30           && ok "first call passes"        || no "first call passes"
hook_cooldown "t-$$" 30           && no "second call suppressed"   || ok "second call suppressed"
hook_cooldown "other-$$" 30       && ok "different key independent" || no "different key independent"

hook_token_valid "real-token-abc"     && ok "real token accepted"      || no "real token accepted"
hook_token_valid ""                   && no "empty rejected"           || ok "empty rejected"
hook_token_valid "YOUR_WEBHOOK_TOKEN" && no "placeholder rejected"     || ok "placeholder rejected"
hook_token_valid "REPLACE_ME"         && no "REPLACE_ME rejected"      || ok "REPLACE_ME rejected"

[ -n "${PYTHON3:-}" ] && ok "PYTHON3 defined" || no "PYTHON3 defined"
echo "PASS=$PASS FAIL=$FAIL"; exit $((FAIL > 0))
```

- [ ] **Step 2: Run it — must fail with "libs/hook-guard.sh missing"**

```bash
bash scripts/tests/test_hook_guard.sh
```

- [ ] **Step 3: Port the library**

```bash
mkdir -p libs && cp ~/.claude/libs/hook-guard.sh libs/hook-guard.sh
```

Then edit `libs/hook-guard.sh`: replace its header comment with a forge header (purpose, install path `~/.claude/libs/hook-guard.sh`, functions provided). Read the file first; if the cooldown state path is hardcoded (e.g. `/tmp/...` or `~/.claude/cache/...`), introduce `HOOK_GUARD_STATE_DIR="${HOOK_GUARD_STATE_DIR:-$HOME/.claude/cache/hook-guard}"` and use it, keeping mtime-based semantics identical. If the test's assumed function names differ from the real ones, fix the TEST to match the library (the library is the shipped contract), and update this task's Interfaces block in the same commit.

- [ ] **Step 4: Run the test — all green; then `bash -n libs/hook-guard.sh`**

- [ ] **Step 5: Wire installers (both, same commit — parity CI enforces)**

`install.sh`: add `libs` to the `for dir in agents rules commands scripts skills hooks cc-chips cc-chips-custom` list AND to the verify list (`for item in ...`). `install.ps1`: add `"libs"` to `$directories` and `$items`. Update `hooks/context-sync-suggest.sh`'s comment: the helper now ships with forge; the guarded source stays (protects Method B plugin-only installs).

- [ ] **Step 6: Verify parity + syntax, then commit**

```bash
bash -n install.sh && bash scripts/tests/test_hook_guard.sh
git add libs/ scripts/tests/test_hook_guard.sh install.sh install.ps1 hooks/context-sync-suggest.sh
git commit -m "feat(libs): ship hook-guard.sh — cooldown/token-guard library hooks already source (S1)"
```

Note: the installer-parity CI reads install.sh's `for dir in` line as truth, so adding `libs` there forces install.ps1 coverage — if you forget the ps1 side, CI fails, which is correct.

---

### Task 3: S5 — doom-loop detection + edit-time verify hooks

**Files:**
- Create: `hooks/loop-detection.sh` (from `~/.claude/hooks/loop-detection.sh`, 51 lines, zero bindings)
- Create: `hooks/auto-verify-fix.sh` (from `~/.claude/hooks/auto-verify-fix.sh`, 134 lines, zero bindings)
- Modify: `settings.json` (hooks block: add `loop-detection.sh` under `PostToolUse` unmatched group; add `auto-verify-fix.sh` under `PostToolUse` matcher `Edit|Write`)
- Modify: `hooks/README.md` (two rows in the event catalog table)

**Interfaces:**
- Consumes: nothing. Both hooks are self-contained; if they source hook-guard.sh they must use the guarded-optional pattern.
- Produces: two registered PostToolUse hooks emitting `additionalContext` JSON only (non-blocking).

- [ ] **Step 1: Port both files, set shebang `#!/bin/bash`, read each for bindings**

```bash
cp ~/.claude/hooks/loop-detection.sh ~/.claude/hooks/auto-verify-fix.sh hooks/
```

Read both. Confirm: no `moshi`/`qjc`/absolute internal paths (recon says zero; verify anyway with `grep -nE 'qjc|moshi|Discord|supabase' hooks/loop-detection.sh hooks/auto-verify-fix.sh` — expect no output). If `auto-verify-fix.sh` calls project-specific build commands, keep its detection generic (it should no-op when no recognized project type).

- [ ] **Step 2: Behavioural smoke test (each hook, clean HOME)**

```bash
T=$(mktemp -d)
printf '%s' '{"tool_name":"Bash","tool_input":{"command":"npm test"},"tool_response":{"stderr":"FAIL"}}' \
  | HOME="$T" bash hooks/loop-detection.sh; echo "rc=$? (must be 0)"
printf '%s' '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/x.py"}}' \
  | HOME="$T" bash hooks/auto-verify-fix.sh; echo "rc=$? (must be 0)"
```

Both must exit 0 (hooks never block the session on their own errors). Any stdout must be valid JSON or empty — pipe through `python3 -m json.tool` when non-empty.

- [ ] **Step 3: Register in settings.json and validate**

Add to the existing `hooks.PostToolUse` array: `loop-detection.sh` in the first (unmatched) group's hooks list, and a `{"matcher": "Edit|Write", "hooks": [{"type": "command", "command": "~/.claude/hooks/auto-verify-fix.sh"}]}` alongside the existing Edit|Write group (append to that group's hooks array rather than adding a duplicate matcher). Then:

```bash
python3 -m json.tool settings.json > /dev/null && echo OK
```

- [ ] **Step 4: Add both to hooks/README.md catalog table, bash -n both, commit**

```bash
bash -n hooks/loop-detection.sh hooks/auto-verify-fix.sh
git add hooks/ settings.json
git commit -m "feat(hooks): doom-loop detection + edit-time verify (S5)"
```

---

### Task 4: S2 — secret commit guard + regression suite

**Files:**
- Create: `scripts/install-precommit.sh` (from `~/qjc-office/dotclaude/scripts/install-precommit.sh` v10)
- Create: `scripts/tests/test_precommit_guard.sh` (from `~/qjc-office/dotclaude/scripts/tests/test_precommit_guard.sh`, 18 cases)
- Modify: `.github/workflows/validate.yml` (new step in `security` job running the suite)
- Modify: `docs/PLUGIN-VS-INSTALL-SH.md` (one row: guard is Method A/manual, not plugin)

**Interfaces:**
- Produces: `scripts/install-precommit.sh` installs `.git/hooks/pre-commit` into the **current repo** by default; `--all <base-dir>` walks a tree (the internal default, demoted to option). Suite runnable as `bash scripts/tests/test_precommit_guard.sh`.

- [ ] **Step 1: Port both files verbatim, then make three edits to the installer**

```bash
cp ~/qjc-office/dotclaude/scripts/install-precommit.sh scripts/
cp ~/qjc-office/dotclaude/scripts/tests/test_precommit_guard.sh scripts/tests/
```

Installer edits (read the file; anchors are exact):
1. Inside `HOOK_CONTENT`, delete section `# 4. 카탈로그/카운트 드리프트 게이트` — the whole `if [ -f "scripts/gen_agent_catalog.py" ]; then ... fi` block (QJC-only; forge has no such scripts). Keep sections 1–3 and `exit 0`.
2. Replace the trailing "find all repos under ~/qjc-office" driver with: default = install into the repo containing `$PWD` (`git rev-parse --git-dir`), `--all <base>` = previous find-based walk over `<base>`. Keep the version-signature SKIP, backup-to-`.bak`, and `chmod +x` logic identical.
3. Header comment: translate to English, keep the v5–v10 changelog contents (they are the earned knowledge: SIGPIPE, ssh-pubkey false positives, placeholder filter, interpreter/grep pinning) but strip internal file paths and the QJC incident framing to one line each.

The hook body's Korean inline comments: translate to English in the same pass (open-source readability). Do not alter any pattern or logic while translating — the suite is the referee.

- [ ] **Step 2: Point the suite at the local installer and run it**

The suite's `INSTALLER=` line must resolve to `scripts/install-precommit.sh` relative to the repo root (it already computes `REPO_ROOT` from `BASH_SOURCE`; verify the relative segment matches forge's layout). Then:

```bash
bash scripts/tests/test_precommit_guard.sh
```

Expected: `PASS=18 FAIL=0`. The multibyte watchdog case must PASS(<15s).

- [ ] **Step 3: End-to-end install check in a throwaway repo**

```bash
D=$(mktemp -d); cd "$D" && git init -q . && git config user.email t@t && git config user.name t
bash /Users/sangrok/qjc-office/claude-forge/scripts/install-precommit.sh
head -2 .git/hooks/pre-commit          # must show the guard header
# fixture assembled at runtime so this plan document itself never contains a
# token-shaped literal (the guard would rightly block committing the plan)
printf 'k = ghp_%s\n' 'A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8' > f.txt && git add f.txt
git commit -m x 2>&1 | head -1          # must print "PRE-COMMIT BLOCKED"
cd /Users/sangrok/qjc-office/claude-forge
```

- [ ] **Step 4: Add CI step (security job, before ShellCheck)**

```yaml
      - name: Secret-guard regression suite
        run: bash scripts/tests/test_precommit_guard.sh
```

Validate: `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/validate.yml'))"`.

- [ ] **Step 5: bash -n both scripts, commit**

```bash
git add scripts/install-precommit.sh scripts/tests/test_precommit_guard.sh .github/workflows/validate.yml docs/PLUGIN-VS-INSTALL-SH.md
git commit -m "feat(scripts): pre-commit secret guard v10 + 18-case regression suite (S2)"
```

---

### Task 5: S4 — session relay + pre-compact snapshot

**Files:**
- Create: `skills/relay/` (SKILL.md, `scripts/relay-lib.sh`, `scripts/relay-collect.sh`, `scripts/relay-build-focus.sh`, `scripts/relay-write-baton.sh`, `tests/relay.bats`; from `~/.claude/skills/relay/` — do NOT port `references/legacy-relay-command.md`)
- Create: `hooks/pre-compact-snapshot.sh` (from `~/.claude/hooks/pre-compact-snapshot.sh`, zero bindings)
- Modify: `settings.json` (add `PreCompact` event entry running the snapshot hook)
- Modify: `hooks/README.md` (PreCompact row now points at a shipped hook instead of an example)

**Interfaces:**
- Consumes: nothing external.
- Produces: `/relay` skill generating a baton document; PreCompact hook snapshotting state; PostCompact restore path documented inside SKILL.md.

- [ ] **Step 1: Port, excluding legacy reference**

```bash
mkdir -p skills/relay && cp -R ~/.claude/skills/relay/SKILL.md ~/.claude/skills/relay/scripts ~/.claude/skills/relay/tests skills/relay/
cp ~/.claude/hooks/pre-compact-snapshot.sh hooks/
```

- [ ] **Step 2: Cut the one binding — TODAY.md task-ledger block**

In `skills/relay/scripts/relay-collect.sh` around lines 123–128 (`# ---- tasks (TODAY.md) ----` … `TASKS_SOURCE="TODAY.md"`): replace the QJC-specific ledger with a generic optional hook — if `RELAY_TASKS_FILE` is set and readable, extract `- [ ]` items from it; otherwise skip the section silently. Sweep the rest: `grep -rnE 'QJC|qjc-office|TODAY' skills/relay/ hooks/pre-compact-snapshot.sh` must return nothing. Also scan SKILL.md for references to the removed legacy file and internal commands; rewrite those sentences.

- [ ] **Step 3: Behavioural test on a fixture repo**

```bash
D=$(mktemp -d); cd "$D" && git init -q . && git config user.email t@t && git config user.name t
echo hi > a.txt && git add a.txt && git commit -qm init && echo change >> a.txt
bash /Users/sangrok/qjc-office/claude-forge/skills/relay/scripts/relay-collect.sh > collect.out; echo "rc=$?"
grep -c "a.txt" collect.out   # baton input must mention the dirty file
cd /Users/sangrok/qjc-office/claude-forge
```

rc must be 0 and the dirty file present. If the skill ships bats tests, also run `bats skills/relay/tests/relay.bats` when `bats` is available; otherwise note in SKILL.md that the suite needs bats (do not add a hard dependency).

- [ ] **Step 4: Register PreCompact in settings.json, validate JSON, bash -n all scripts, commit**

```bash
python3 -m json.tool settings.json > /dev/null
bash -n hooks/pre-compact-snapshot.sh skills/relay/scripts/*.sh
git add skills/relay hooks/pre-compact-snapshot.sh settings.json hooks/README.md
git commit -m "feat(skills): session relay + pre-compact snapshot (S4)"
```

---

### Task 6: S3 — API-error auto-resume

**Files:**
- Create: `hooks/api-error-auto-resume.sh` (from `~/.claude/hooks/api-error-auto-resume.sh`, 323 lines)
- Create: `scripts/api-error-resume-runner.sh` (from `~/.claude/scripts/api-error-resume-runner.sh`, 559 lines)
- Create: `rules/api-error-recovery.md` (condensed from `~/qjc-office/dotclaude/rules/api-error-auto-resume.md`: contract, resume paths, guard caps, env vars, kill switch — drop internal incident log)
- Create: `scripts/tests/test_auto_resume_classify.sh`
- Modify: `settings.json` (add `StopFailure` event entry), `hooks/README.md` (StopFailure row)

**Interfaces:**
- Consumes: optionally `libs/hook-guard.sh` (guarded source).
- Produces: StopFailure hook + detached runner. Notification contract: `notify()` shell function that runs `$FORGE_NOTIFY_CMD "<title>" "<message>"` when set, else no-op.

- [ ] **Step 1: Port both files, apply the four documented cuts**

```bash
cp ~/.claude/hooks/api-error-auto-resume.sh hooks/
cp ~/.claude/scripts/api-error-resume-runner.sh scripts/
```

Cuts (anchors verified against source on 2026-08-18):
1. **Runner lines ~84–88 and ~401–406** (two `moshi-send.sh` blocks): replace each with the notify shim. Define once near the top of the runner:

```bash
# Pluggable notification: set FORGE_NOTIFY_CMD to any command taking
# "<title>" "<message>" (e.g. a curl wrapper). Unset = silent no-op.
notify() {
    [ -n "${FORGE_NOTIFY_CMD:-}" ] || return 0
    "$FORGE_NOTIFY_CMD" "$1" "$2" 2>/dev/null || true
}
```

Call sites become `notify "Auto-resume disabled" "Runaway guard tripped: $*"` and `notify "Auto-resume executed" "Session ${SESSION_ID:0:8} auto-resumed after API error (rc=$rc)"`.
2. **Runner lines ~329–361** (qgate load-gate block): delete the qgate status function and its wait loop; where the wait was invoked, proceed directly (keep the surrounding log line, reworded "load gate not configured — proceeding").
3. **Hook lines ~86–87** (`accounts exhausted` / `all accounts` proxy signals) and **runner line ~113** RATE regex: remove those two phrases from the retry-signal lists (proxy-rotation specific). Keep `rate limit`, `429`, `usage limit`, `retry in`.
4. **Hook classification comment block**: strip references to TeamClaude; keep the RETRY/SKIP contract table.
Also sweep: `grep -nE 'moshi|qgate|teamclaude|TeamClaude|accounts exhausted' hooks/api-error-auto-resume.sh scripts/api-error-resume-runner.sh` → must return nothing.

- [ ] **Step 2: Write the classification test**

Create `scripts/tests/test_auto_resume_classify.sh` — runs the hook with `CLAUDE_AUTO_RESUME_DRY_RUN=1`, isolated HOME, feeding fixture StopFailure payloads on stdin, asserting the logged verdict:

```bash
#!/bin/bash
set -uo pipefail
HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/hooks/api-error-auto-resume.sh"
PASS=0; FAIL=0
check() { # name payload expect(RETRY|SKIP)
  local T; T=$(mktemp -d)
  printf '%s' "$2" | HOME="$T" CLAUDE_AUTO_RESUME_DRY_RUN=1 bash "$HOOK" >/dev/null 2>&1 || true
  local log="$T/.claude/logs/api-error-auto-resume.log"
  if [ -f "$log" ] && grep -q "$3" "$log"; then printf '  ok   %s\n' "$1"; PASS=$((PASS+1))
  else printf '  FAIL %s (want %s)\n' "$1" "$3"; [ -f "$log" ] && tail -2 "$log"; FAIL=$((FAIL+1)); fi
}
check "overloaded → RETRY" '{"session_id":"s1","stop_reason":"error","error_type":"overloaded","error":"Overloaded"}' RETRY
check "500 → RETRY"        '{"session_id":"s2","stop_reason":"error","error":"API Error: 500 internal_error"}' RETRY
check "billing → SKIP"     '{"session_id":"s3","stop_reason":"error","error_type":"billing_error","error":"billing"}' SKIP
check "auth → SKIP"        '{"session_id":"s4","stop_reason":"error","error_type":"authentication_failed","error":"auth"}' SKIP
check "plain 429 → SKIP"   '{"session_id":"s5","stop_reason":"error","error":"API Error: 429 rate_limit"}' SKIP
echo "PASS=$PASS FAIL=$FAIL"; exit $((FAIL > 0))
```

Read the hook first: if log path or verdict words differ (e.g. it logs `SCHEDULE` instead of `RETRY`), align the TEST to the hook's real contract and note the words in rules/api-error-recovery.md.

- [ ] **Step 3: Run the test to green; bash -n both files**

- [ ] **Step 4: Write `rules/api-error-recovery.md`** — sections: When it fires / RETRY vs SKIP table / resume paths (dead vs tmux vs takeover, with the takeover safety: idle 2-factor check + progress-aware cap) / caps table (3-per-6h rolling, lock, stagger) / env vars incl. `FORGE_NOTIFY_CMD` / kill switch (`CLAUDE_AUTO_RESUME_DISABLED=1` or the DISABLED file) / platform note (takeover path uses macOS `ps` flags — verify or degrade gracefully on Linux; state what was actually tested).

- [ ] **Step 5: Register StopFailure in settings.json, validate, commit**

```bash
python3 -m json.tool settings.json > /dev/null
git add hooks/api-error-auto-resume.sh scripts/api-error-resume-runner.sh rules/api-error-recovery.md scripts/tests/test_auto_resume_classify.sh settings.json hooks/README.md
git commit -m "feat(hooks): unattended API-error auto-resume with fork-bomb guards (S3)"
```

Spec fallback: if genericization stalls (>1 review round on safety), drop this task, revert its commits, and note in MIGRATION that S3 moved to v4.1 — the release ships 8 sets.

---

### Task 7: S6 — adversarial verification set (flagship)

**Files:**
- Create: `agents/adversarial-reviewer.md` (from `~/.claude/agents/adversarial-reviewer.md`, 60 lines; 3 gate references to cut)
- Create: `agents/skeptical-auditor.md` (from `~/.claude/agents/skeptical-auditor.md`, 180 lines, zero bindings)
- Create: `skills/review-loop/SKILL.md` (+ `references/` if portable; from `~/.claude/skills/review-loop/`, 104 lines)
- Create: `rules/adversarial-review.md` (new writing, ~60 lines)
- Create: `docs/VERIFICATION-LOOP.md` (worked example)

**Interfaces:**
- Consumes: nothing (agents are read-only checkers: tools `["Read", "Grep", "Glob", "Bash"]`).
- Produces: verdict contract `forge.review/v1` — JSON envelope `{schema, verdict: APPROVE|REQUEST_CHANGES|UNVERIFIED, findings: [{severity, location, description, suggestion}], evidence_checked: [], summary}`. Task 11's README section references `docs/VERIFICATION-LOOP.md`.

- [ ] **Step 1: Port the two agents; cut gate references**

In `adversarial-reviewer.md`, locate the 3 lines matching `grep -nE 'gate|receipt|qjc' agents/adversarial-reviewer.md` and remove/reword: the checker must not reference the internal deterministic gate CLI, receipts, or nonce issuance. Replace the verdict schema name (`qjc.adversarial-review/v1` or similar) with `forge.review/v1`. Confirm frontmatter `tools` is the read-only set above and passes `reference/agent-schema.json` (jsonschema check from CI, run locally as in Task 1 Step 2 but with the agents validator).

- [ ] **Step 2: Port review-loop SKILL; strip gate/receipt machinery**

Read `~/.claude/skills/review-loop/SKILL.md` + references. Keep: the loop state machine (implement → dispatch fresh checker → verdict → fix → re-dispatch until APPROVE), maker≠checker rule (checker session must not have authored the change; fork/self-review forbidden), verdict semantics (UNVERIFIED is not a pass; a dead reviewer is not approval), re-verification etiquette (tell the checker what changed, ask it to re-reproduce, invite attack on the fix itself). Cut: anything invoking gate CLI, SHA pinning, seatbelt, receipts, or internal hooks. The SKILL's dispatch instruction should use the generic Task/Agent tool phrasing (forge users may not have Agent Teams).

- [ ] **Step 3: Write `rules/adversarial-review.md`** — the rule layer: when the loop is mandatory (behavioural changes), the three verdicts and what each obligates, the "reviewer death ≠ approval" clause, checker independence definition, and the escalation (2 consecutive REQUEST_CHANGES on the same finding → stop and surface to the human).

- [ ] **Step 4: Write `docs/VERIFICATION-LOOP.md`** — a worked example. Use the real 2026-08-18 dogfooding story genericized: maker adds a CI guard; reviewer reproduces a false-pass (comment containing the guarded word), maker fixes with AST parsing, reviewer finds first-assignment-only gap, second fix, APPROVE. Show one full verdict envelope in `forge.review/v1` format. No internal repo names needed beyond claude-forge itself (it is this repo's own history — link PR #58/#61).

- [ ] **Step 5: Validate all frontmatter + commit**

```bash
python3 - <<'EOF'
import json, re, yaml
from pathlib import Path
from jsonschema import validate
schema = json.loads(Path('reference/agent-schema.json').read_text())
for p in ['agents/adversarial-reviewer.md', 'agents/skeptical-auditor.md']:
    m = re.match(r'^---\n(.*?)\n---\n', Path(p).read_text(), re.DOTALL)
    validate(yaml.safe_load(m.group(1)), schema); print('OK', p)
EOF
git add agents/adversarial-reviewer.md agents/skeptical-auditor.md skills/review-loop rules/adversarial-review.md docs/VERIFICATION-LOOP.md
git commit -m "feat(agents,skills): adversarial verification loop — maker≠checker until APPROVE (S6)"
```

---

### Task 8: S7 — debugging escalation chain agents

**Files:**
- Create: `agents/systematic-debugger.md`, `agents/rca-debugger.md`, `agents/escalation-fixer.md` (from `~/.claude/agents/` same names)

**Interfaces:**
- Consumes: `skills/systematic-debugging/` (Task 1) as methodology reference — cited in prose, not as a frontmatter `skills:` dependency.
- Produces: three agents; escalation order documented in each description: build-error-resolver (compile) → systematic-debugger (reproducible runtime) → rca-debugger (bisect inconclusive / flaky / cross-layer) → escalation-fixer (last resort, architectural changes allowed, reads escalation-log.json).

- [ ] **Step 1: Port and remap**

```bash
cp ~/.claude/agents/systematic-debugger.md ~/.claude/agents/rca-debugger.md ~/.claude/agents/escalation-fixer.md agents/
```

Per file: (a) frontmatter `tools`: rewrite `mcp__chrome__list_console_messages` → `mcp__chrome-devtools__list_console_messages` (same for every `mcp__chrome__*`), `mcp__plugin_playwright_playwright__browser_console_messages` → `mcp__playwright__browser_console_messages` (same pattern for all); (b) remove `superpowers:*` entries from any `skills:` frontmatter key and convert to a prose line "methodology: see skills/systematic-debugging" where apt (2 references each in systematic/rca); (c) sweep `grep -nE 'qjc|QJC|worktree-collision|dotclaude' agents/systematic-debugger.md agents/rca-debugger.md agents/escalation-fixer.md` → nothing; (d) if frontmatter carries `isolation: worktree`, keep it (native feature, not QJC).

- [ ] **Step 2: Schema-validate all three (same jsonschema snippet as Task 7 Step 5, with the three paths), commit**

```bash
git add agents/systematic-debugger.md agents/rca-debugger.md agents/escalation-fixer.md
git commit -m "feat(agents): debugging escalation chain — systematic → rca → escalation-fixer (S7)"
```

---

### Task 9: S8 — task-grade routing on top of /workflow-classify

**Files:**
- Modify: `commands/workflow-classify.md` (merged in Task 1)
- Create: `rules/task-grade-routing.md` (~40 lines, condensed from internal `documentation-routing.md` 29 lines + ref)

**Interfaces:**
- Consumes: PR #23's S/M/L/XL grades.
- Produces: per-grade routing table used by the rule and echoed in the command's output section.

- [ ] **Step 1: Read PR #23's classifier; map internal grades onto it**

Internal uses XS/S/M/L; PR #23 uses S/M/L/XL. Adopt **the contributor's axis** (S/M/L/XL) and translate the internal mapping onto it: S = no persistent docs (goal/constraints/done-when inline), targeted check; M = micro-spec 4 items (Goal/Non-goals/Acceptance/Test), targeted check + 1 independent review lane on behavioural change; L = permanent spec + plan before code, 1 adversarial lane; XL = full spec + decision record + rollout/rollback + approval gate before implementation, 2+ independent lanes. Escalation floor: auth/payments/PII/RLS/secrets boundaries/irreversible deploys are minimum XL regardless of size (non-destructive schema/API contract changes minimum L).

- [ ] **Step 2: Write `rules/task-grade-routing.md`** with that table + the "reviewer death ≠ pass" cross-reference to `rules/adversarial-review.md`, and extend `commands/workflow-classify.md`'s output format so a classification always prints its documentation + verification obligations.

- [ ] **Step 3: Frontmatter check (argument-hint string), commit**

```bash
git add commands/workflow-classify.md rules/task-grade-routing.md
git commit -m "feat(commands,rules): per-grade documentation and verification routing on /workflow-classify (S8)"
```

---

### Task 10: S9 — Korean writing quality set

**Files:**
- Create: `rules/korean-writing-quality.md` (from internal rule, 102 lines)
- Create: `reference/ai-tell-taxonomy.md` (from internal, 608 lines)
- Create: `hooks/emdash-slop-guard.sh` (64 lines) + `scripts/emdash_slop_check.py` (76 lines, zero bindings)
- Create: `scripts/tests/test_emdash_check.py`
- Create: `skills/humanize-korean/` (SKILL.md + references, lite rewrite), `skills/korean-character-count/`, `skills/korean-spell-check/` (both vendored as-is)
- Modify: `settings.json` (emdash guard under PostToolUse Edit|Write group)

**Interfaces:**
- Produces: `python3 scripts/emdash_slop_check.py <file>` exit 0/1 with tagged findings (`body`/`heading`); rule + taxonomy as standalone docs; three skills passing frontmatter CI.

- [ ] **Step 1: Port rule + taxonomy; cut the 3 QJC references in the rule**

`grep -nE 'QJC|qjc|copywriting|Sonnet' rules/korean-writing-quality.md` after copy → rewrite those lines: model-routing clauses ("카피 생성=Sonnet", copywriting agent delegation) become a generic note ("발화체 카피는 별도 검수 권장"); the L3 vendor-surface section (§5) becomes a two-line generic warning about sending sensitive text to third-party model surfaces; internal file cross-references (`reviewer-team.md`, `anti-slop-design.md`, `eoche-check`) drop or point to shipped counterparts only. Taxonomy: sweep for client names (`grep -nE '위키북스|고객|거래' reference/ai-tell-taxonomy.md` — keep the 편집부 anecdote only if anonymized to "출판사 편집부").

- [ ] **Step 2: Port emdash guard + checker; write the fixture test**

`scripts/tests/test_emdash_check.py` (pytest-free, plain asserts, run with `python3`):

```python
import subprocess, sys, tempfile, pathlib
CHECK = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "emdash_slop_check.py"
def run(text):
    f = tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8")
    f.write(text); f.close()
    p = subprocess.run([sys.executable, str(CHECK), f.name], capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr
rc, out = run("본문에 줄표 삽입구 — 이런 형태 — 가 있다.\n")
assert rc != 0 and "body" in out, f"body interjection must be flagged: {out}"
rc, out = run("## 제목 — 부제 구분자\n본문.\n")
assert rc != 0 and "heading" in out, f"heading separator must be flagged: {out}"
rc, out = run("| — |\n수치 범위 100-200px는 대상 아님.\n")
assert rc == 0, f"table-cell dash and numeric ranges must pass: {out}"
print("OK: 3 cases")
```

Read the checker first; if its CLI or tag words differ, align the test to the shipped contract. Run to green.

- [ ] **Step 3: Vendored skills + humanize-lite**

Copy `korean-character-count`, `korean-spell-check` as-is (verify their `skill.json`/scripts carry no network calls to internal services: `grep -rnE 'supabase|qjc|moshi' skills/korean-*`). For `humanize-korean`: port SKILL.md + references but rewrite the routing sections — single-pass lite only, no 5-persona pipeline, no L3 platform-routing table (replaced by the generic sensitive-text warning), description trigger text in Korean+English.

- [ ] **Step 4: Register emdash guard hook (Edit|Write group), validate everything, commit**

```bash
python3 -m json.tool settings.json > /dev/null
python3 scripts/tests/test_emdash_check.py
bash -n hooks/emdash-slop-guard.sh
# skills frontmatter check — reuse the CI snippet from Task 1 Step 2 over the three new SKILL.md files
git add rules/korean-writing-quality.md reference/ai-tell-taxonomy.md hooks/emdash-slop-guard.sh scripts/emdash_slop_check.py scripts/tests/test_emdash_check.py skills/humanize-korean skills/korean-character-count skills/korean-spell-check settings.json
git commit -m "feat(korean): writing-quality rule, AI-tell taxonomy, emdash guard, 3 skills (S9)"
```

---

### Task 11: Docs, inventory, version 4.0.0

**Files:**
- Create: `docs/RELIABILITY.md` (S1–S5 wiring guide: what each hook does, how to enable/disable, env vars, platform matrix)
- Modify: `README.md`, `README.ko.md`, `README.zh.md` (v4.0 banner + three feature sections; Korean pack gets one line in en/zh, full section in ko)
- Modify: `MIGRATION.md`, `MIGRATION.ko.md` (v3→v4 section: new events wired — StopFailure/PreCompact, new libs/ dir, secret guard opt-in command)
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (version 4.0.0 ×3 slots, description counts), `docs/MARKETPLACE-SUBMISSION.md` (Current version row), README file-tree version refs (the doc-version-sync CI patterns)

**Interfaces:**
- Consumes: everything above, complete.

- [ ] **Step 1: Measure real inventory — never hand-count**

```bash
echo "agents=$(ls agents/*.md | wc -l) commands=$(ls commands/*.md | wc -l) skills=$(ls -d skills/*/ | wc -l) hooks=$(ls hooks/*.sh | wc -l) rules=$(ls rules/*.md | wc -l) libs=$(ls libs/*.sh | wc -l)"
```

Use these numbers verbatim in plugin.json description, marketplace.json (both), README×3, MIGRATION.

- [ ] **Step 2: Write docs; bump versions; update banners**

Version bump exactly as v3.1.1 did (three JSON slots + `| Current version |` row + README tree refs). Banner leads with the flagship: the adversarial loop, with the PR #58/#61 dogfooding line. README.ko gets the Korean-pack section.

- [ ] **Step 3: Reproduce every CI job locally (the full v3.1.1 checklist)**

```bash
python3 -m json.tool settings.json .claude-plugin/plugin.json .claude-plugin/marketplace.json > /dev/null
PJV=$(jq -r '.version' .claude-plugin/plugin.json); MJV=$(jq -r '.version' .claude-plugin/marketplace.json); MPV=$(jq -r '.plugins[]|select(.name=="claude-forge")|.version' .claude-plugin/marketplace.json)
[ "$PJV" = "4.0.0" ] && [ "$MJV" = "$MPV" ] && [ "$PJV" = "$MJV" ] && echo "version OK"
bash -n install.sh && ./install.sh --upgrade --dry-run | grep -q "core MCP entries present" && echo "installer OK"
bash scripts/tests/test_precommit_guard.sh && bash scripts/tests/test_hook_guard.sh && bash scripts/tests/test_auto_resume_classify.sh && python3 scripts/tests/test_emdash_check.py
```

All green, then relative-link sweep over new docs (the python link checker used in v3.1.1) and commit:

```bash
git add -A docs README.md README.ko.md README.zh.md MIGRATION.md MIGRATION.ko.md .claude-plugin
git commit -m "docs(release): v4.0.0 — inventory, migration, reliability + verification guides"
```

---

### Task 12: Backlog issues, release PR, adversarial review

**Files:** none in-repo (GitHub operations + review dispatch)

- [ ] **Step 1: File 13 v4.1 backlog issues** — one per deferred set from spec §5, each with its survey rationale (2–3 sentences from `~/.claude/artifacts/forge-port-survey-20260818/REPORT.md`) and a `help wanted` label where external-contributor-friendly (pull-main, push-before-ci, dry-run preview, karpathy-check, sprint-contract).

- [ ] **Step 2: Open the release PR** `release/v4.0` → `main`, body: pack summaries, per-set source attribution ("ported from the maintainer's internal harness"), external contributions credited (#23, #24), CI evidence, and the dogfooding narrative.

- [ ] **Step 3: Per-pack adversarial review (the shipped S6 process, dogfooded)** — three fresh checkers in isolated worktrees (pack 1 = Tasks 2/3/4/5/6, pack 2 = Tasks 1/7/8/9, pack 3 = Task 10), each instructed to reproduce rather than trust, with the standing instruction: *if you install anything (brew etc.), uninstall/unlink before reporting*. Fix findings, re-verify to APPROVE.

- [ ] **Step 4: Merge on 16/16 CI + three APPROVEs; tag `v4.0.0`; verify remote**

```bash
gh pr merge --squash <PR>   # or merge commit if history per-set is preferred — decide at review time
git tag v4.0.0 && git push origin v4.0.0
curl -s https://raw.githubusercontent.com/sangrokjung/claude-forge/main/.claude-plugin/plugin.json | python3 -c "import json,sys; assert json.load(sys.stdin)['version']=='4.0.0'; print('remote 4.0.0 OK')"
```

---

## Self-Review Notes

- Spec coverage: S1→T2, S2→T4, S3→T6, S4→T5, S5→T3, S6→T7, S7→T1+T8, S8→T1+T9, S9→T10; spec §4 mechanics→T11/T12; spec §5 deferrals→T12 Step 1; S3 fallback clause carried into T6 verbatim. No gaps found.
- Placeholders: none — every cut has a grep-verifiable anchor; tests carry full code. Where a source file's internal contract may differ from the test sketch (T2 S3 function names, T6 S2 verdict words, T10 S2 CLI tags), the plan states the resolution rule explicitly: the shipped source is the contract, align the test, update Interfaces in the same commit.
- Type consistency: notify shim name (`notify`/`FORGE_NOTIFY_CMD`) consistent across T6 and Global Constraint 2; verdict schema `forge.review/v1` consistent across T7 and T12; grade axis S/M/L/XL consistent across T1/T9.
