#!/usr/bin/env bash
# dashboard-chip.sh — cc-chips integration for project dashboard
# Outputs one-line status for current project from cached scan results.
#
# Usage (called by cc-chips engine):
#   bash scripts/dashboard-chip.sh
#
# Output format:
#   [Score: 85] [Tests: ✓] [Issues: 3]
#
# Performance requirement: Must complete under 100ms (reads cache only).

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────

CACHE_FILE="$HOME/.claude/.dashboard-cache.json"

# ── Main Logic ───────────────────────────────────────────────────────

# Exit silently if cache doesn't exist
if [[ ! -f "$CACHE_FILE" ]]; then
  exit 0
fi

# Get current directory (normalize path using realpath)
CURRENT_DIR="$(cd "$(pwd)" && pwd -P)"

# Read cache and find matching project (case-insensitive match for macOS)
PROJECT_DATA=$(jq -r --arg path "$CURRENT_DIR" '.[] | select((.path | ascii_downcase) == ($path | ascii_downcase))' "$CACHE_FILE" 2>/dev/null || echo "")

# If current project not in cache, exit silently
if [[ -z "$PROJECT_DATA" ]]; then
  exit 0
fi

# Extract metrics
SECURITY_SCORE=$(echo "$PROJECT_DATA" | jq -r '.security_score')
TEST_COVERAGE=$(echo "$PROJECT_DATA" | jq -r '.test_coverage')
OPEN_ISSUES=$(echo "$PROJECT_DATA" | jq -r '.open_issues')
PENDING_PRS=$(echo "$PROJECT_DATA" | jq -r '.pending_prs')

# Format output for cc-chips
OUTPUT=""

# Security score chip
if [[ $SECURITY_SCORE -ge 80 ]]; then
  OUTPUT+="[Score: ${SECURITY_SCORE} ✓] "
elif [[ $SECURITY_SCORE -ge 60 ]]; then
  OUTPUT+="[Score: ${SECURITY_SCORE} ⚠] "
else
  OUTPUT+="[Score: ${SECURITY_SCORE} ✗] "
fi

# Test coverage chip
if [[ $TEST_COVERAGE -ge 80 ]]; then
  OUTPUT+="[Tests: ${TEST_COVERAGE}% ✓] "
elif [[ $TEST_COVERAGE -gt 0 ]]; then
  OUTPUT+="[Tests: ${TEST_COVERAGE}%] "
else
  OUTPUT+="[Tests: ✗] "
fi

# Issues chip (only show if > 0)
if [[ $OPEN_ISSUES -gt 0 ]]; then
  OUTPUT+="[Issues: ${OPEN_ISSUES}] "
fi

# PRs chip (only show if > 0)
if [[ $PENDING_PRS -gt 0 ]]; then
  OUTPUT+="[PRs: ${PENDING_PRS}] "
fi

# Output (trimmed)
echo "${OUTPUT% }"
