#!/usr/bin/env bash
# audit-export.sh — Export audit logs in JSON or CSV format
#
# Usage:
#   bash scripts/audit-export.sh --format csv --days 30 --output report.csv
#   bash scripts/audit-export.sh --format json --days 7
#   bash scripts/audit-export.sh --format csv --type security --days 14
#
# Or source as a library:
#   source scripts/audit-export.sh
#   export_audit "csv" 30 "report.csv"

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────

AUDIT_BASE_DIR="${AUDIT_BASE_DIR:-$HOME/.claude/audit}"
AUDIT_SECURITY_DIR="${AUDIT_BASE_DIR}/security"

# ── Helpers ──────────────────────────────────────────────────────────

# Collect log files for a given period and type
_collect_log_files() {
  local days="${1:-7}"
  local log_type="${2:-all}"

  local search_dir="$AUDIT_BASE_DIR"
  if [[ "$log_type" == "security" ]]; then
    search_dir="$AUDIT_SECURITY_DIR"
  fi

  if [[ ! -d "$search_dir" ]]; then
    return 0
  fi

  find "$search_dir" -maxdepth 1 -name "*.jsonl" -type f -mtime -"$days" | sort
}

# ── Export Functions ─────────────────────────────────────────────────

# export_audit(format, days, output_file, type)
#   format: json|csv
#   days: number of days to include
#   output_file: optional output path (stdout if empty)
#   type: all|security (default: all)
export_audit() {
  local format="${1:-json}"
  local days="${2:-7}"
  local output_file="${3:-}"
  local log_type="${4:-all}"

  local files
  files=$(_collect_log_files "$days" "$log_type")

  if [[ -z "$files" ]]; then
    echo "No audit logs found for the last ${days} days." >&2
    return 0
  fi

  case "$format" in
    json)
      _export_json "$files" "$output_file"
      ;;
    csv)
      _export_csv "$files" "$output_file"
      ;;
    *)
      echo "Error: Unsupported format '$format'. Use 'json' or 'csv'." >&2
      return 1
      ;;
  esac
}

# Export as JSON (array of entries)
_export_json() {
  local files="$1"
  local output_file="${2:-}"

  local result
  # shellcheck disable=SC2086
  result=$(cat $files | jq -s '.' 2>/dev/null || echo '[]')

  if [[ -n "$output_file" ]]; then
    echo "$result" > "$output_file"
    echo "Exported $(echo "$result" | jq 'length') entries to ${output_file}" >&2
  else
    echo "$result"
  fi
}

# Export as CSV with headers
_export_csv() {
  local files="$1"
  local output_file="${2:-}"

  local csv_header="timestamp,user,action,target,result"
  local csv_body
  # shellcheck disable=SC2086
  csv_body=$(cat $files \
    | jq -r '[
        .timestamp // "",
        .user // "",
        (.action // .event_type // ""),
        (.target // .details.tool_name // ""),
        (.result // .severity // "")
      ] | @csv' 2>/dev/null || echo "")

  if [[ -n "$output_file" ]]; then
    {
      echo "$csv_header"
      echo "$csv_body"
    } > "$output_file"
    local line_count
    line_count=$(echo "$csv_body" | grep -c . || echo "0")
    echo "Exported ${line_count} entries to ${output_file}" >&2
  else
    echo "$csv_header"
    echo "$csv_body"
  fi
}

# ── Summary Statistics ───────────────────────────────────────────────

# audit_summary(days)
#   Print summary statistics for the given period.
audit_summary() {
  local days="${1:-7}"

  local all_files sec_files
  all_files=$(_collect_log_files "$days" "all")
  sec_files=$(_collect_log_files "$days" "security")

  local total_events=0
  local security_events=0
  local failure_count=0

  if [[ -n "$all_files" ]]; then
    # shellcheck disable=SC2086
    total_events=$(cat $all_files | wc -l | tr -d ' ')
    # shellcheck disable=SC2086
    failure_count=$(cat $all_files | jq -r 'select(.result == "failure")' 2>/dev/null | grep -c '"result"' || echo "0")
  fi

  if [[ -n "$sec_files" ]]; then
    # shellcheck disable=SC2086
    security_events=$(cat $sec_files | wc -l | tr -d ' ')
  fi

  local failure_rate="0.0"
  if [[ "$total_events" -gt 0 ]]; then
    failure_rate=$(python3 -c "print(f'{($failure_count / $total_events) * 100:.1f}')" 2>/dev/null || echo "0.0")
  fi

  local sessions=0
  if [[ -n "$all_files" ]]; then
    # shellcheck disable=SC2086
    sessions=$(cat $all_files | jq -r '.metadata.session_id // empty' 2>/dev/null | sort -u | grep -c . || echo "0")
  fi

  echo "=== Audit Summary (Last ${days} days) ==="
  echo ""
  echo "  Total events:    ${total_events}"
  echo "  Security events: ${security_events}"
  echo "  Active sessions: ${sessions}"
  echo "  Failure rate:    ${failure_rate}%"
  echo ""

  # Top 5 actions
  if [[ -n "$all_files" ]]; then
    echo "Top 5 Actions:"
    echo "  Rank  Action          Count"
    # shellcheck disable=SC2086
    cat $all_files \
      | jq -r '.target // .action // "unknown"' 2>/dev/null \
      | sort \
      | uniq -c \
      | sort -rn \
      | head -n 5 \
      | awk '{printf "  %-6s %-15s %s\n", NR, $2, $1}'
    echo ""
  fi
}

# ── CLI Interface ────────────────────────────────────────────────────

_print_usage() {
  echo "Usage: audit-export.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --format FORMAT   Output format: json, csv (default: json)"
  echo "  --days N          Number of days to include (default: 7)"
  echo "  --output FILE     Output file path (default: stdout)"
  echo "  --type TYPE       Log type: all, security (default: all)"
  echo "  --summary         Print summary statistics instead of raw export"
  echo "  -h, --help        Show this help message"
}

_cli_main() {
  local format="json"
  local days=7
  local output_file=""
  local log_type="all"
  local summary_mode=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --format)
        format="${2:-json}"
        shift 2
        ;;
      --days)
        days="${2:-7}"
        shift 2
        ;;
      --output)
        output_file="${2:-}"
        shift 2
        ;;
      --type)
        log_type="${2:-all}"
        shift 2
        ;;
      --summary)
        summary_mode=true
        shift
        ;;
      -h|--help)
        _print_usage
        return 0
        ;;
      *)
        echo "Error: Unknown option '$1'" >&2
        _print_usage >&2
        return 1
        ;;
    esac
  done

  if [[ "$summary_mode" == true ]]; then
    audit_summary "$days"
  else
    export_audit "$format" "$days" "$output_file" "$log_type"
  fi
}

# ── Direct Execution ─────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  _cli_main "$@"
fi
