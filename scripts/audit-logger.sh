#!/usr/bin/env bash
# audit-logger.sh — Core audit logging library for Claude Forge
# Structured JSON-lines (.jsonl) audit logs with daily rotation.
#
# Usage:
#   source scripts/audit-logger.sh
#   log_audit "tool" "Bash" "success" '{"command":"ls"}'
#   log_security_event "secret_detected" '{"file":"config.ts"}'
#   cleanup_old_logs 14
#
# Or run directly for self-test:
#   bash scripts/audit-logger.sh --self-test

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────

AUDIT_BASE_DIR="${AUDIT_BASE_DIR:-$HOME/.claude/audit}"
AUDIT_SECURITY_DIR="${AUDIT_BASE_DIR}/security"
AUDIT_DATE_FORMAT="+%Y-%m-%d"
AUDIT_TS_FORMAT="+%Y-%m-%dT%H:%M:%S%z"

# ── Directory Setup ──────────────────────────────────────────────────

ensure_audit_dirs() {
  mkdir -p "$AUDIT_BASE_DIR" "$AUDIT_SECURITY_DIR"
}

# ── Helpers ──────────────────────────────────────────────────────────

# Get current date string for log file naming
_audit_date() {
  date "$AUDIT_DATE_FORMAT"
}

# Get ISO8601 timestamp
_audit_timestamp() {
  date "$AUDIT_TS_FORMAT"
}

# Get current git branch (empty string if not in a repo)
_audit_git_branch() {
  git branch --show-current 2>/dev/null || echo ""
}

# Sanitize a string for safe JSON embedding via jq
_audit_safe_json() {
  local val="${1:-}"
  printf '%s' "$val" | jq -Rs '.' 2>/dev/null || echo '""'
}

# ── Core Logging ─────────────────────────────────────────────────────

# log_audit(action, target, result, metadata_json)
#   action: command|agent|hook|tool
#   target: what was executed
#   result: success|failure
#   metadata_json: optional JSON object string (default: {})
log_audit() {
  local action="${1:-unknown}"
  local target="${2:-}"
  local result="${3:-unknown}"
  local metadata="${4:-{\}}"

  ensure_audit_dirs

  local log_file="${AUDIT_BASE_DIR}/$(_audit_date).jsonl"
  local timestamp
  timestamp="$(_audit_timestamp)"
  local user
  user="$(whoami)"
  local branch
  branch="$(_audit_git_branch)"
  local session_id="${CLAUDE_SESSION_ID:-}"

  # Build the JSON entry using jq for safe encoding
  local entry
  entry=$(jq -nc \
    --arg ts "$timestamp" \
    --arg user "$user" \
    --arg action "$action" \
    --arg target "$target" \
    --arg result "$result" \
    --arg session_id "$session_id" \
    --arg branch "$branch" \
    --argjson metadata "$metadata" \
    '{
      timestamp: $ts,
      user: $user,
      action: $action,
      target: $target,
      result: $result,
      metadata: ($metadata + {
        session_id: $session_id,
        branch: $branch
      })
    }') || return 0

  echo "$entry" >> "$log_file"
}

# ── Security Event Logging ───────────────────────────────────────────

# log_security_event(event_type, details_json)
#   event_type: secret_detected|unauthorized_access|permission_denied|etc
#   details_json: optional JSON object string (default: {})
log_security_event() {
  local event_type="${1:-unknown}"
  local details="${2:-{\}}"

  ensure_audit_dirs

  local log_file="${AUDIT_SECURITY_DIR}/$(_audit_date).jsonl"
  local timestamp
  timestamp="$(_audit_timestamp)"
  local user
  user="$(whoami)"
  local branch
  branch="$(_audit_git_branch)"
  local session_id="${CLAUDE_SESSION_ID:-}"

  local entry
  entry=$(jq -nc \
    --arg ts "$timestamp" \
    --arg user "$user" \
    --arg event_type "$event_type" \
    --arg session_id "$session_id" \
    --arg branch "$branch" \
    --argjson details "$details" \
    '{
      timestamp: $ts,
      user: $user,
      event_type: $event_type,
      severity: "security",
      details: ($details + {
        session_id: $session_id,
        branch: $branch
      })
    }') || return 0

  echo "$entry" >> "$log_file"

  # Also write to the main audit log for unified querying
  log_audit "security" "$event_type" "alert" "$details"
}

# ── Log Cleanup ──────────────────────────────────────────────────────

# cleanup_old_logs(days)
#   Remove audit log files older than N days.
#   Defaults to 14 days (matching cleanupPeriodDays).
cleanup_old_logs() {
  local days="${1:-14}"

  ensure_audit_dirs

  # Clean main audit logs
  find "$AUDIT_BASE_DIR" -maxdepth 1 -name "*.jsonl" -type f -mtime +"$days" -delete 2>/dev/null || true

  # Clean security logs
  find "$AUDIT_SECURITY_DIR" -maxdepth 1 -name "*.jsonl" -type f -mtime +"$days" -delete 2>/dev/null || true
}

# ── Query Helpers ────────────────────────────────────────────────────

# get_audit_files(days, type)
#   Returns list of audit log files for the given period.
#   type: "all" (default) | "security"
get_audit_files() {
  local days="${1:-7}"
  local log_type="${2:-all}"

  ensure_audit_dirs

  local search_dir="$AUDIT_BASE_DIR"
  if [[ "$log_type" == "security" ]]; then
    search_dir="$AUDIT_SECURITY_DIR"
  fi

  find "$search_dir" -maxdepth 1 -name "*.jsonl" -type f -mtime -"$days" | sort
}

# count_events(days, type)
#   Returns total event count for the given period.
count_events() {
  local days="${1:-7}"
  local log_type="${2:-all}"
  local total=0

  while IFS= read -r file; do
    local count
    count=$(wc -l < "$file" | tr -d ' ')
    total=$((total + count))
  done < <(get_audit_files "$days" "$log_type")

  echo "$total"
}

# top_actions(days, limit)
#   Returns top N most frequent actions.
top_actions() {
  local days="${1:-7}"
  local limit="${2:-5}"

  local files
  files=$(get_audit_files "$days" "all")

  if [[ -z "$files" ]]; then
    echo "No audit data found."
    return 0
  fi

  # shellcheck disable=SC2086
  cat $files \
    | jq -r '.target // .action' 2>/dev/null \
    | sort \
    | uniq -c \
    | sort -rn \
    | head -n "$limit"
}

# ── Self-Test ────────────────────────────────────────────────────────

_audit_self_test() {
  local test_dir
  test_dir=$(mktemp -d)
  AUDIT_BASE_DIR="$test_dir/audit"
  AUDIT_SECURITY_DIR="$AUDIT_BASE_DIR/security"

  echo "=== Audit Logger Self-Test ==="

  # Test 1: log_audit
  log_audit "tool" "Bash" "success" '{"command":"ls -la"}'
  local log_file="${AUDIT_BASE_DIR}/$(_audit_date).jsonl"
  if [[ -f "$log_file" ]]; then
    echo "PASS: log_audit created log file"
    jq '.' "$log_file"
  else
    echo "FAIL: log_audit did not create log file"
  fi

  # Test 2: log_security_event
  log_security_event "secret_detected" '{"file":"config.ts","pattern":"API_KEY"}'
  local sec_file="${AUDIT_SECURITY_DIR}/$(_audit_date).jsonl"
  if [[ -f "$sec_file" ]]; then
    echo "PASS: log_security_event created security log"
    jq '.' "$sec_file"
  else
    echo "FAIL: log_security_event did not create security log"
  fi

  # Test 3: count_events
  local count
  count=$(count_events 1 "all")
  if [[ "$count" -ge 2 ]]; then
    echo "PASS: count_events returned $count (expected >= 2)"
  else
    echo "FAIL: count_events returned $count (expected >= 2)"
  fi

  # Cleanup test dir
  rm -rf "$test_dir"
  echo "=== Self-Test Complete ==="
}

# ── Direct Execution ─────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    --self-test)
      _audit_self_test
      ;;
    --cleanup)
      cleanup_old_logs "${2:-14}"
      echo "Cleanup complete (removed logs older than ${2:-14} days)"
      ;;
    *)
      echo "Usage: audit-logger.sh [--self-test|--cleanup DAYS]"
      echo ""
      echo "This is primarily a library. Source it in your scripts:"
      echo "  source scripts/audit-logger.sh"
      echo ""
      echo "Functions: log_audit, log_security_event, cleanup_old_logs"
      ;;
  esac
fi
