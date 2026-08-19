#!/bin/bash
# relay-collect.sh — deterministic state collector.
# Think of it as a snapshot photo (JSON) of the desk before stepping away: which branch, how many
# uncommitted changes, how far the plan got.
#
# Output: one JSON object on stdout. Always exits 0 (never dies on missing git/files — fail-open).
# Intentionally does not use `set -e` (must never abort on missing input).
set -o pipefail

# ---- small helper: truncate a long string ----
_trunc() {
  local s="$1" max="${2:-2000}"
  if [ "${#s}" -gt "$max" ]; then
    printf '%s' "${s:0:$max}…"
  else
    printf '%s' "$s"
  fi
}

# ---- basic meta ----
PROJECT_NAME="$(basename "$PWD" 2>/dev/null || echo '')"
CWD="$PWD"
TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo '')"
HOSTNAME_S="$(hostname -s 2>/dev/null || echo '')"
OS_S="$(uname -s 2>/dev/null || echo '')"

# ---- git ----
GIT_IS_REPO=false
GIT_BRANCH=""
GIT_UNCOMMITTED=0
GIT_STATUS=""
GIT_DIFFSTAT=""
GIT_LOG_JSON="[]"

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  GIT_IS_REPO=true
  GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '')"
  GIT_UNCOMMITTED="$(git status --short 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
  GIT_STATUS="$(git status --short 2>/dev/null | head -30 || echo '')"
  GIT_DIFFSTAT="$(git diff --stat 2>/dev/null | tail -21 || echo '')"
  GIT_LOG_JSON="$(git log -10 --pretty=format:'%h%x1f%s' 2>/dev/null | python3 -c '
import sys, json
out = []
for line in sys.stdin.read().splitlines():
    if not line.strip():
        continue
    parts = line.split("\x1f", 1)
    h = parts[0]
    subj = parts[1] if len(parts) > 1 else ""
    out.append({"hash": h, "subject": subj})
sys.stdout.write(json.dumps(out, ensure_ascii=False))
' 2>/dev/null || echo '[]')"
fi

# numeric/JSON sanity fixups
case "$GIT_UNCOMMITTED" in ''|*[!0-9]*) GIT_UNCOMMITTED=0 ;; esac
echo "$GIT_LOG_JSON" | jq -e . >/dev/null 2>&1 || GIT_LOG_JSON='[]'
GIT_STATUS="$(_trunc "$GIT_STATUS" 2000)"
GIT_DIFFSTAT="$(_trunc "$GIT_DIFFSTAT" 2000)"

# ---- plan.md ----
PLAN_EXISTS=false
PLAN_STATUS=""
PLAN_DONE=0
PLAN_UNCHECKED=0
PLAN_TOTAL=0
PLAN_NEXT=""
PLAN_FILE=".claude/plan.md"
if [ -f "$PLAN_FILE" ]; then
  PLAN_EXISTS=true
  PLAN_DONE="$(grep -cE '^[[:space:]]*- \[x\]' "$PLAN_FILE" 2>/dev/null || true)"
  PLAN_UNCHECKED="$(grep -cE '^[[:space:]]*- \[ \]' "$PLAN_FILE" 2>/dev/null || true)"
  case "$PLAN_DONE" in ''|*[!0-9]*) PLAN_DONE=0 ;; esac
  case "$PLAN_UNCHECKED" in ''|*[!0-9]*) PLAN_UNCHECKED=0 ;; esac
  PLAN_TOTAL=$((PLAN_DONE + PLAN_UNCHECKED))
  PLAN_STATUS="$(grep -E -m1 'STATUS[: ]' "$PLAN_FILE" 2>/dev/null | grep -oE 'APPROVED|DRAFT|REVIEWING' | head -1 || true)"
  PLAN_NEXT="$(grep -E -m1 '^[[:space:]]*- \[ \]' "$PLAN_FILE" 2>/dev/null | sed -E 's/^[[:space:]]*- \[ \][[:space:]]*//' || true)"
  PLAN_NEXT="$(_trunc "$PLAN_NEXT" 500)"
fi

# ---- auto-loop-todo.md ----
ALT_EXISTS=false
ALT_NEXT=""
ALT_FILE=".claude/auto-loop-todo.md"
if [ -f "$ALT_FILE" ]; then
  ALT_EXISTS=true
  ALT_NEXT="$(grep -E -m1 '^[[:space:]]*- \[ \]' "$ALT_FILE" 2>/dev/null | sed -E 's/^[[:space:]]*- \[ \][[:space:]]*//' || true)"
  ALT_NEXT="$(_trunc "$ALT_NEXT" 500)"
fi

# ---- sprint-contract.md ----
SC_EXISTS=false
if [ -f ".claude/sprint-contract.md" ] || [ -f "sprint-contract.md" ]; then
  SC_EXISTS=true
fi

# ---- session summary (work-log) ----
SS_EXISTS=false
SS_FRESH=false
SS_PATH=""
SS_SUMMARY=""
SS_NEXT_JSON="[]"
SS_BLOCK_JSON="[]"
WL_DIR="$HOME/.claude/work-log"
if [ -d "$WL_DIR" ]; then
  SS_PATH="$(ls -t "$WL_DIR"/session-summary-*.json 2>/dev/null | head -1 || true)"
  if [ -n "$SS_PATH" ] && [ -f "$SS_PATH" ]; then
    SS_EXISTS=true
    # fresh if within the last 24 hours
    if find "$SS_PATH" -mmin -1440 2>/dev/null | grep -q .; then
      SS_FRESH=true
    fi
    # JSON parsing (empty values on failure)
    SS_SUMMARY="$(jq -r '.summary // empty' "$SS_PATH" 2>/dev/null || true)"
    SS_SUMMARY="$(_trunc "$SS_SUMMARY" 1500)"
    SS_NEXT_JSON="$(jq -c '(.next_steps // []) | if type=="array" then . else [] end' "$SS_PATH" 2>/dev/null || echo '[]')"
    SS_BLOCK_JSON="$(jq -c '(.blockers // []) | if type=="array" then . else [] end' "$SS_PATH" 2>/dev/null || echo '[]')"
  fi
fi
echo "$SS_NEXT_JSON" | jq -e . >/dev/null 2>&1 || SS_NEXT_JSON='[]'
echo "$SS_BLOCK_JSON" | jq -e . >/dev/null 2>&1 || SS_BLOCK_JSON='[]'

# ---- tasks (optional external task ledger) ----
# Generic hook: if RELAY_TASKS_FILE is set and readable, pull "- [ ]" items from it.
# Otherwise skip this section silently (no hardcoded project-specific task file path).
TASKS_SOURCE="none"
TASKS_JSON="[]"
if [ -n "${RELAY_TASKS_FILE:-}" ] && [ -f "${RELAY_TASKS_FILE}" ]; then
  TASKS_SOURCE="$RELAY_TASKS_FILE"
  TASKS_JSON="$(grep -E '^[[:space:]]*- \[ \]' "$RELAY_TASKS_FILE" 2>/dev/null | sed -E 's/^[[:space:]]*- \[ \][[:space:]]*//' | head -5 | python3 -c '
import sys, json
items = [l for l in sys.stdin.read().splitlines() if l.strip()]
sys.stdout.write(json.dumps(items, ensure_ascii=False))
' 2>/dev/null || echo '[]')"
fi
echo "$TASKS_JSON" | jq -e . >/dev/null 2>&1 || TASKS_JSON='[]'

# ---- artifacts ----
ART_COUNT=0
ART_JSON="[]"
ART_DIR=".claude/artifacts"
if [ -d "$ART_DIR" ]; then
  ART_COUNT="$(find "$ART_DIR" -type f 2>/dev/null | wc -l | tr -d ' ' || echo 0)"
  case "$ART_COUNT" in ''|*[!0-9]*) ART_COUNT=0 ;; esac
  ART_JSON="$(find "$ART_DIR" -type f 2>/dev/null | head -5 | sed 's#.*/##' | python3 -c '
import sys, json
items = [l for l in sys.stdin.read().splitlines() if l]
sys.stdout.write(json.dumps(items, ensure_ascii=False))
' 2>/dev/null || echo '[]')"
fi
echo "$ART_JSON" | jq -e . >/dev/null 2>&1 || ART_JSON='[]'

# ---- assemble JSON (jq -n for safe escaping) ----
jq -n \
  --arg project_name "$PROJECT_NAME" \
  --arg cwd "$CWD" \
  --arg timestamp "$TIMESTAMP" \
  --arg hostname "$HOSTNAME_S" \
  --arg os "$OS_S" \
  --argjson git_is_repo "$GIT_IS_REPO" \
  --arg git_branch "$GIT_BRANCH" \
  --argjson git_uncommitted "$GIT_UNCOMMITTED" \
  --arg git_status "$GIT_STATUS" \
  --argjson git_log "$GIT_LOG_JSON" \
  --arg git_diffstat "$GIT_DIFFSTAT" \
  --argjson plan_exists "$PLAN_EXISTS" \
  --arg plan_status "$PLAN_STATUS" \
  --argjson plan_total "$PLAN_TOTAL" \
  --argjson plan_done "$PLAN_DONE" \
  --arg plan_next "$PLAN_NEXT" \
  --argjson alt_exists "$ALT_EXISTS" \
  --arg alt_next "$ALT_NEXT" \
  --argjson sc_exists "$SC_EXISTS" \
  --argjson ss_exists "$SS_EXISTS" \
  --argjson ss_fresh "$SS_FRESH" \
  --arg ss_path "$SS_PATH" \
  --arg ss_summary "$SS_SUMMARY" \
  --argjson ss_next "$SS_NEXT_JSON" \
  --argjson ss_block "$SS_BLOCK_JSON" \
  --arg tasks_source "$TASKS_SOURCE" \
  --argjson tasks_items "$TASKS_JSON" \
  --argjson art_count "$ART_COUNT" \
  --argjson art_sample "$ART_JSON" \
  '{
    project_name: $project_name,
    cwd: $cwd,
    timestamp: $timestamp,
    hostname: $hostname,
    os: $os,
    git: {
      is_repo: $git_is_repo,
      branch: ($git_branch | if . == "" then null else . end),
      uncommitted_count: $git_uncommitted,
      status_short: $git_status,
      log: $git_log,
      diff_stat: $git_diffstat
    },
    plan: {
      exists: $plan_exists,
      status: ($plan_status | if . == "" then null else . end),
      total: $plan_total,
      done: $plan_done,
      next_unchecked: ($plan_next | if . == "" then null else . end)
    },
    auto_loop_todo: {
      exists: $alt_exists,
      next_unchecked: ($alt_next | if . == "" then null else . end)
    },
    sprint_contract: { exists: $sc_exists },
    session_summary: {
      exists: $ss_exists,
      fresh: $ss_fresh,
      path: ($ss_path | if . == "" then null else . end),
      summary: ($ss_summary | if . == "" then null else . end),
      next_steps: $ss_next,
      blockers: $ss_block
    },
    tasks: { source: $tasks_source, items: $tasks_items },
    artifacts: { count: $art_count, sample: $art_sample }
  }' 2>/dev/null || echo '{}'

exit 0
