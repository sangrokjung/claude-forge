#!/bin/bash
# relay-write-baton.sh — atomically write the baton (next-session handoff doc) + pointer + clipboard + lint.
# Think of it as handing the next runner the baton without fumbling (atomic mv), while also stashing a
# copy in the trackside locker (pointer). Even at 95% context, the skeleton always gets written.
#
# Args:
#   $1 = NEXT_TASK (required)
#   $2 = COLLECT_JSON (file path, or '-' = stdin)
#   $3 = FOCUS_LINE  (the `/compact` one-liner produced by relay-build-focus.sh)
#   $4 = PROSE_FILE  (optional; the model's §2/§4 prose in markdown. Skeleton alone is still valid without it.)
#
# Output: the last stdout line = absolute path of the baton. exit 0 on success, exit 3 on structural lint failure.
# Intentionally does not use `set -e` (a side-effect failure should not block the skeleton write). Only -u/pipefail.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=relay-lib.sh
source "$SCRIPT_DIR/relay-lib.sh"

NEXT_TASK="${1:-}"
COLLECT_SRC="${2:-}"
FOCUS_LINE="${3:-}"
PROSE_FILE="${4:-}"

if [ -z "$(printf '%s' "$NEXT_TASK" | tr -d '[:space:]')" ]; then
  echo "[relay-write-baton] Error: NEXT_TASK is empty." >&2
  exit 2
fi

# ---- read collect JSON ----
COLLECT_JSON='{}'
if [ "$COLLECT_SRC" = "-" ]; then
  COLLECT_JSON="$(cat 2>/dev/null || echo '{}')"
elif [ -n "$COLLECT_SRC" ] && [ -f "$COLLECT_SRC" ]; then
  COLLECT_JSON="$(cat "$COLLECT_SRC" 2>/dev/null || echo '{}')"
fi
echo "$COLLECT_JSON" | jq -e . >/dev/null 2>&1 || COLLECT_JSON='{}'

# ---- extract fields ----
jqget() { printf '%s' "$COLLECT_JSON" | jq -r "$1" 2>/dev/null || true; }
jqraw() { printf '%s' "$COLLECT_JSON" | jq -r "$1" 2>/dev/null || true; }

PROJ="$(jqget '.project_name // empty')"
[ -z "$PROJ" ] && PROJ="$(basename "$PWD")"
ABS_CWD="$(jqget '.cwd // empty')"
[ -z "$ABS_CWD" ] && ABS_CWD="$PWD"
BRANCH="$(jqget '.git.branch // "?"')"
[ -z "$BRANCH" ] && BRANCH="?"
UNCOMMITTED="$(jqget '.git.uncommitted_count // 0')"
case "$UNCOMMITTED" in ''|*[!0-9]*) UNCOMMITTED=0 ;; esac
PLAN_DONE="$(jqget '.plan.done // 0')"
case "$PLAN_DONE" in ''|*[!0-9]*) PLAN_DONE=0 ;; esac
PLAN_TOTAL="$(jqget '.plan.total // 0')"
case "$PLAN_TOTAL" in ''|*[!0-9]*) PLAN_TOTAL=0 ;; esac
PLAN_NEXT="$(jqget '.plan.next_unchecked // empty')"
ALT_NEXT="$(jqget '.auto_loop_todo.next_unchecked // empty')"
SS_NEXT_STEPS="$(jqraw '(.session_summary.next_steps // []) | .[]')"
TASK_ITEMS="$(jqraw '(.tasks.items // []) | .[]')"
BLOCKERS="$(jqraw '(.session_summary.blockers // []) | .[]')"

# ---- first actions (up to 3, from plan next / alt / next_steps / tasks) ----
CAND="$(printf '%s\n%s\n%s\n%s\n' "$PLAN_NEXT" "$ALT_NEXT" "$SS_NEXT_STEPS" "$TASK_ITEMS")"
ACTION_LINES="$(printf '%s\n' "$CAND" | awk 'NF' | awk '!seen[$0]++' | head -3)"
if [ -n "$ACTION_LINES" ]; then
  FIRST_ACTIONS="$(printf '%s\n' "$ACTION_LINES" | awk '{printf "%d. %s\n", NR, $0}')"
else
  FIRST_ACTIONS="First action: (needs to be defined — break the next task into 1-3 concrete steps)"
fi

# completion condition (binary)
COMPLETION="Done when the next task is reflected in code/docs and the related tests/build pass (green)."

# blocker block
BLOCKER_BLOCK=""
if [ -n "$BLOCKERS" ]; then
  BLOCKER_BLOCK="$(printf '%s\n' "$BLOCKERS" | awk 'NF{printf "- Blocker: %s\n", $0}')"
fi

# ---- split PROSE: §2 / §4 based on the '---§4---' marker ----
PROSE_S2=""
PROSE_S4=""
if [ -n "$PROSE_FILE" ] && [ -f "$PROSE_FILE" ]; then
  if grep -q '^---§4---$' "$PROSE_FILE" 2>/dev/null; then
    PROSE_S2="$(sed -n '1,/^---§4---$/p' "$PROSE_FILE" | sed '$d')"
    PROSE_S4="$(sed -n '/^---§4---$/,$p' "$PROSE_FILE" | sed '1d')"
  else
    PROSE_S2="$(cat "$PROSE_FILE" 2>/dev/null || true)"
  fi
fi

S2="$PROSE_S2"
if [ -z "$(printf '%s' "$S2" | tr -d '[:space:]')" ]; then
  S2="(to be filled by the prose pass — KEEP only context whose keywords/file paths overlap the next task. Summarize side items in one line; facts should quote the §6 snapshot JSON verbatim.)"
fi
S4="$PROSE_S4"
if [ -z "$(printf '%s' "$S4" | tr -d '[:space:]')" ]; then
  S4="(no notable pitfalls — add during the prose pass if found, e.g. missing env vars, needs a cache clear, order-dependent steps.)"
fi

# ---- paths/timestamps ----
HASH="$(relay_cwd_hash "$ABS_CWD")"
RDIR="$(relay_dir)"
mkdir -p "$RDIR" 2>/dev/null || true
TS="$(date '+%Y%m%d-%H%M%S')"
ISO="$(date '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S' 2>/dev/null || echo '')"

# filename sanitization (strip spaces/slashes)
PROJ_SAFE="$(printf '%s' "$PROJ" | tr ' /' '__')"
[ -z "$PROJ_SAFE" ] && PROJ_SAFE="project"

# ---- save the collect JSON snapshot (for §6 recovery reference) ----
COLLECT_SAVE="$RDIR/.collect-${HASH}-${TS}.json"
printf '%s\n' "$COLLECT_JSON" > "$COLLECT_SAVE" 2>/dev/null || true

# ---- write the baton (atomically) ----
BATON="$RDIR/relay-${PROJ_SAFE}-${TS}.md"
TMP="$BATON.tmp.$$"

{
  printf '# Relay baton — %s\n' "$PROJ"
  printf '> Mode: continue in-place (`/compact`). For a brand-new session, paste this entire baton into the new session.\n\n'

  printf '## 0. `/compact` one-liner (in-place only — copy and paste)\n'
  printf '```\n'
  printf '%s\n' "$FOCUS_LINE"
  printf '```\n\n'

  printf '## 1. MISSION (next task)\n'
  printf '%s\n\n' "$NEXT_TASK"
  printf 'Completion: %s\n\n' "$COMPLETION"
  printf 'First actions:\n%s\n\n' "$FIRST_ACTIONS"

  printf '## 2. Context needed (KEEP-only, filtered by next task)\n'
  printf '%s\n\n' "$S2"

  printf '## 3. Current state\n'
  printf -- '- Branch: %s\n' "$BRANCH"
  printf -- '- Uncommitted: %s\n' "$UNCOMMITTED"
  printf -- '- Plan: %s/%s\n' "$PLAN_DONE" "$PLAN_TOTAL"
  if [ -n "$BLOCKER_BLOCK" ]; then
    printf '%s\n' "$BLOCKER_BLOCK"
  fi
  printf '\n'

  printf '## 4. Repro pitfalls / gotchas\n'
  printf '%s\n\n' "$S4"

  printf '## 5. Start command\n'
  printf '```\n'
  printf 'cd %s\n' "$ABS_CWD"
  printf 'git status\n'
  printf '```\n\n'

  printf '## 6. Reference (for recovery)\n'
  printf -- '- Collect snapshot (JSON): %s\n' "$COLLECT_SAVE"
  printf -- '- Quote facts verbatim from that JSON. No inline bulk dumps.\n'
} > "$TMP" 2>/dev/null

mv "$TMP" "$BATON" 2>/dev/null || {
  echo "[relay-write-baton] Error: failed to move baton ($TMP -> $BATON)" >&2
  rm -f "$TMP" 2>/dev/null || true
  exit 3
}

# ---- update the pointer (for PostCompact auto-restore) ----
CARRYOVER="$(printf 'Next task: %s\nCompletion: %s\nFirst actions:\n%s\n/compact: %s' "$NEXT_TASK" "$COMPLETION" "$FIRST_ACTIONS" "$FOCUS_LINE")"
if [ "${#CARRYOVER}" -gt 1500 ]; then
  CARRYOVER="${CARRYOVER:0:1499}…"
fi
POINTER="$(relay_pointer_path "$HASH")"
jq -n \
  --arg cwd "$ABS_CWD" \
  --arg baton "$BATON" \
  --arg next_task "$NEXT_TASK" \
  --arg carryover "$CARRYOVER" \
  --arg created "$ISO" \
  --argjson ttl 12 \
  '{cwd:$cwd, baton:$baton, next_task:$next_task, carryover:$carryover, created:$created, ttl_hours:$ttl}' \
  > "$POINTER" 2>/dev/null || true

# a new baton means a fresh start -> clear any existing consumed marker
rm -f "$(relay_consumed_path "$HASH")" 2>/dev/null || true

# record the path of the most recent baton
printf '%s\n' "$BATON" > "$(relay_last_path)" 2>/dev/null || true

# ---- clipboard: disabled by default ----
# The clipboard must not be the primary delivery channel. It's a single, volatile slot — if the user
# copies something else in the meantime, FOCUS_LINE is gone, and whatever was there before gets silently
# overwritten without consent. The primary channel is the code block in chat scrollback — persistent and
# re-readable. Opt in explicitly with RELAY_COPY=1 (the skill's `--copy` flag) if clipboard is really needed.
if [ "${RELAY_COPY:-}" = "1" ]; then
  CLIP_TMP="$RDIR/.clip.$$"
  printf '%s' "$FOCUS_LINE" > "$CLIP_TMP" 2>/dev/null || true
  relay_clipboard_copy "$CLIP_TMP" || true
  rm -f "$CLIP_TMP" 2>/dev/null || true
fi

# ---- structural lint (re-read after mv) ----
# NOTE: uses herestrings (<<<), not `printf | grep -q`. grep -q exits as soon as it finds a
# match, which can SIGPIPE-kill printf before it finishes writing; under `set -o pipefail`
# that turns a successful match into a false failure. Herestrings avoid the pipe entirely.
LINT_OK=1
BCONTENT="$(cat "$BATON" 2>/dev/null || true)"
grep -q '## 1' <<< "$BCONTENT" || LINT_OK=0
grep -qF -- "$NEXT_TASK" <<< "$BCONTENT" || LINT_OK=0
grep -qE '^cd /' <<< "$BCONTENT" || LINT_OK=0
if grep -qiE 'see other file' <<< "$BCONTENT"; then
  LINT_OK=0
fi

if [ "$LINT_OK" -ne 1 ]; then
  echo "[relay-write-baton] Structural lint failed (file exists on disk): $BATON" >&2
  echo "$BATON"
  exit 3
fi

echo "$BATON"
exit 0
