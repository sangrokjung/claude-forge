#!/usr/bin/env bash
# project-scanner.sh — Multi-project status scanner for Claude Forge
# Collects project health metrics: security, tests, issues, PRs, activity.
#
# Usage:
#   source scripts/project-scanner.sh
#   scan_project ~/my-app
#   scan_all_projects ~/Projects
#   get_project_summary ~/my-app
#   compare_security ~/app1 ~/app2
#   security_recommendations ~/my-app
#
# Or run directly:
#   bash scripts/project-scanner.sh --scan /path/to/project
#   bash scripts/project-scanner.sh --scan-all ~/Projects

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Security Score Calculation ───────────────────────────────────────

# Calculate security score (0-100) based on file checks
_security_score() {
  local project_path="$1"
  local score=100
  local deductions=()

  # Check 1: CLAUDE.md exists (+10 if exists, -10 if missing)
  if [[ ! -f "$project_path/CLAUDE.md" ]]; then
    score=$((score - 10))
    deductions+=("Missing CLAUDE.md")
  fi

  # Check 2: .gitignore has secrets patterns (+10 if good, -15 if missing)
  if [[ -f "$project_path/.gitignore" ]]; then
    if ! grep -qE '(\.env|secret|credential|\.pem|\.key)' "$project_path/.gitignore" 2>/dev/null; then
      score=$((score - 15))
      deductions+=("Weak .gitignore (no secret patterns)")
    fi
  else
    score=$((score - 15))
    deductions+=("Missing .gitignore")
  fi

  # Check 3: No hardcoded secrets in common config files (-30 if found)
  local hardcoded_found=0
  if [[ -d "$project_path/src" ]] || [[ -d "$project_path/config" ]]; then
    while IFS= read -r file; do
      if grep -qE '(api[_-]?key|secret|password|token)\s*=\s*["\047][^"\047]{10,}' "$file" 2>/dev/null; then
        hardcoded_found=1
        break
      fi
    done < <(find "$project_path" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.go" \) 2>/dev/null | head -50)
  fi
  if [[ $hardcoded_found -eq 1 ]]; then
    score=$((score - 30))
    deductions+=("Hardcoded secrets detected")
  fi

  # Check 4: Has security rules in .github or docs (-10 if missing)
  if [[ ! -f "$project_path/.github/SECURITY.md" ]] && \
     [[ ! -f "$project_path/SECURITY.md" ]] && \
     [[ ! -f "$project_path/docs/security.md" ]]; then
    score=$((score - 10))
    deductions+=("No SECURITY.md")
  fi

  # Check 5: package.json has no critical vuln warnings (-15 if npm audit fails)
  if [[ -f "$project_path/package.json" ]]; then
    if command -v npm &>/dev/null; then
      if ! npm audit --audit-level=critical --prefix "$project_path" &>/dev/null; then
        score=$((score - 15))
        deductions+=("npm audit critical vulnerabilities")
      fi
    fi
  fi

  # Ensure score is within bounds
  if [[ $score -lt 0 ]]; then
    score=0
  fi

  echo "$score"
}

# Get security recommendations for a project
security_recommendations() {
  local project_path="$1"
  local recommendations=()

  if [[ ! -f "$project_path/CLAUDE.md" ]]; then
    recommendations+=("Add CLAUDE.md with project context")
  fi

  if [[ ! -f "$project_path/.gitignore" ]] || \
     ! grep -qE '(\.env|secret|credential)' "$project_path/.gitignore" 2>/dev/null; then
    recommendations+=("Add secret patterns to .gitignore (.env, *.pem, etc)")
  fi

  if [[ ! -f "$project_path/.github/SECURITY.md" ]] && \
     [[ ! -f "$project_path/SECURITY.md" ]]; then
    recommendations+=("Create SECURITY.md with vulnerability reporting process")
  fi

  if [[ -f "$project_path/package.json" ]] && command -v npm &>/dev/null; then
    if ! npm audit --audit-level=critical --prefix "$project_path" &>/dev/null; then
      recommendations+=("Run 'npm audit fix' to patch vulnerabilities")
    fi
  fi

  # Check for exposed secrets in files
  local has_secrets=0
  if [[ -d "$project_path/src" ]] || [[ -d "$project_path/config" ]]; then
    if find "$project_path" -type f \( -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.go" \) 2>/dev/null | \
       head -50 | xargs grep -qE '(api[_-]?key|secret|password|token)\s*=\s*["\047][^"\047]{10,}' 2>/dev/null; then
      has_secrets=1
    fi
  fi
  if [[ $has_secrets -eq 1 ]]; then
    recommendations+=("Move hardcoded secrets to environment variables")
  fi

  if [[ ${#recommendations[@]} -eq 0 ]]; then
    echo "No recommendations. Security posture looks good."
  else
    printf '%s\n' "${recommendations[@]}"
  fi
}

# ── Test Coverage Detection ──────────────────────────────────────────

# Detect test coverage (0-100) based on test framework presence
_test_coverage() {
  local project_path="$1"
  local coverage=0

  # Detect test framework
  local has_tests=0

  # JavaScript/TypeScript: Jest, Vitest, Mocha
  if [[ -f "$project_path/package.json" ]]; then
    if grep -qE '"(jest|vitest|mocha|ava)"' "$project_path/package.json" 2>/dev/null; then
      has_tests=1
      # Check for test files
      local test_count
      test_count=$(find "$project_path" -type f \( -name "*.test.*" -o -name "*.spec.*" \) 2>/dev/null | wc -l | tr -d ' ')
      if [[ $test_count -gt 0 ]]; then
        coverage=78  # Base coverage for having tests
        # Check for coverage config
        if [[ -f "$project_path/jest.config.js" ]] || \
           [[ -f "$project_path/vitest.config.ts" ]] || \
           grep -q "coverageThreshold" "$project_path/package.json" 2>/dev/null; then
          coverage=92  # Higher if coverage configured
        fi
      fi
    fi
  fi

  # Python: pytest, unittest
  if [[ -f "$project_path/pytest.ini" ]] || \
     [[ -f "$project_path/setup.py" ]] || \
     [[ -f "$project_path/pyproject.toml" ]]; then
    local py_test_count
    py_test_count=$(find "$project_path" -type f -name "test_*.py" 2>/dev/null | wc -l | tr -d ' ')
    if [[ $py_test_count -gt 0 ]]; then
      has_tests=1
      coverage=75
      if [[ -f "$project_path/.coveragerc" ]] || grep -q "coverage" "$project_path/pyproject.toml" 2>/dev/null; then
        coverage=88
      fi
    fi
  fi

  # Go: go test
  if [[ -f "$project_path/go.mod" ]]; then
    local go_test_count
    go_test_count=$(find "$project_path" -type f -name "*_test.go" 2>/dev/null | wc -l | tr -d ' ')
    if [[ $go_test_count -gt 0 ]]; then
      has_tests=1
      coverage=82
    fi
  fi

  echo "$coverage"
}

# ── GitHub Integration ───────────────────────────────────────────────

# Get open issues count (requires gh CLI)
_open_issues() {
  local project_path="$1"

  if ! command -v gh &>/dev/null; then
    echo "0"
    return
  fi

  if [[ ! -d "$project_path/.git" ]]; then
    echo "0"
    return
  fi

  local count
  count=$(gh issue list --repo "$(git -C "$project_path" remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/')" --state open --limit 1000 --json number 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
  echo "$count"
}

# Get pending PRs count (requires gh CLI)
_pending_prs() {
  local project_path="$1"

  if ! command -v gh &>/dev/null; then
    echo "0"
    return
  fi

  if [[ ! -d "$project_path/.git" ]]; then
    echo "0"
    return
  fi

  local count
  count=$(gh pr list --repo "$(git -C "$project_path" remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]\(.*\)\.git/\1/')" --state open --limit 1000 --json number 2>/dev/null | jq 'length' 2>/dev/null || echo "0")
  echo "$count"
}

# ── Last Activity Detection ──────────────────────────────────────────

# Get last activity timestamp (ISO8601)
_last_activity() {
  local project_path="$1"

  if [[ -d "$project_path/.git" ]]; then
    # Get last commit time
    local timestamp
    timestamp=$(git -C "$project_path" log -1 --format=%cI 2>/dev/null || echo "")
    if [[ -n "$timestamp" ]]; then
      echo "$timestamp"
      return
    fi
  fi

  # Fallback: last modified time of any file
  local last_mod
  last_mod=$(find "$project_path" -type f -not -path "*/.*" -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | awk '{print $1}')
  if [[ -n "$last_mod" ]]; then
    date -r "$last_mod" '+%Y-%m-%dT%H:%M:%S%z' 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# ── Core Functions ───────────────────────────────────────────────────

# scan_project(project_path) — Collect project status as JSON
scan_project() {
  local project_path="$1"

  # Validate path
  if [[ ! -d "$project_path" ]]; then
    echo "{\"error\":\"Project path does not exist\"}" >&2
    return 1
  fi

  # Extract project name
  local name
  name="$(basename "$project_path")"

  # Collect metrics
  local security_score
  security_score="$(_security_score "$project_path")"

  local test_coverage
  test_coverage="$(_test_coverage "$project_path")"

  local open_issues
  open_issues="$(_open_issues "$project_path")"

  local pending_prs
  pending_prs="$(_pending_prs "$project_path")"

  local last_activity
  last_activity="$(_last_activity "$project_path")"

  # Build JSON output
  jq -nc \
    --arg name "$name" \
    --arg path "$project_path" \
    --arg last_activity "$last_activity" \
    --arg security_score "$security_score" \
    --arg test_coverage "$test_coverage" \
    --arg open_issues "$open_issues" \
    --arg pending_prs "$pending_prs" \
    '{
      name: $name,
      path: $path,
      last_activity: $last_activity,
      security_score: ($security_score | tonumber),
      test_coverage: ($test_coverage | tonumber),
      open_issues: ($open_issues | tonumber),
      pending_prs: ($pending_prs | tonumber)
    }'
}

# scan_all_projects(base_dir) — Scan all git repos under a base directory
scan_all_projects() {
  local base_dir="${1:-.}"

  if [[ ! -d "$base_dir" ]]; then
    echo "[]"
    return
  fi

  local projects=()

  # Find all git repositories
  while IFS= read -r repo_path; do
    local result
    result="$(scan_project "$repo_path")"
    if [[ -n "$result" ]]; then
      projects+=("$result")
    fi
  done < <(find "$base_dir" -maxdepth 3 -type d -name ".git" 2>/dev/null | sed 's|/.git$||')

  # Combine into JSON array
  if [[ ${#projects[@]} -eq 0 ]]; then
    echo "[]"
  else
    printf '%s\n' "${projects[@]}" | jq -s '.'
  fi
}

# get_project_summary(project_path) — One-line summary string
get_project_summary() {
  local project_path="$1"

  local name
  name="$(basename "$project_path")"

  local security_score
  security_score="$(_security_score "$project_path")"

  local test_coverage
  test_coverage="$(_test_coverage "$project_path")"

  local open_issues
  open_issues="$(_open_issues "$project_path")"

  echo "$name: Security ${security_score}/100, Tests ${test_coverage}%, Issues ${open_issues}"
}

# compare_security(project_paths...) — Compare security scores across projects
compare_security() {
  local projects=()

  for project_path in "$@"; do
    if [[ ! -d "$project_path" ]]; then
      continue
    fi

    local name
    name="$(basename "$project_path")"

    local score
    score="$(_security_score "$project_path")"

    projects+=("$(printf '%03d\t%s\t%s' "$score" "$name" "$project_path")")
  done

  # Sort by score (descending)
  printf '%s\n' "${projects[@]}" | sort -rn | awk -F'\t' '{printf "%s: %d/100 (%s)\n", $2, $1, $3}'
}

# ── Direct Execution ─────────────────────────────────────────────────

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-}" in
    --scan)
      scan_project "${2:-.}"
      ;;
    --scan-all)
      scan_all_projects "${2:-$HOME/Projects}"
      ;;
    --summary)
      get_project_summary "${2:-.}"
      ;;
    --compare)
      shift
      compare_security "$@"
      ;;
    --recommendations)
      security_recommendations "${2:-.}"
      ;;
    *)
      echo "Usage: project-scanner.sh [COMMAND] [ARGS]"
      echo ""
      echo "Commands:"
      echo "  --scan PATH             Scan a single project (outputs JSON)"
      echo "  --scan-all BASE_DIR     Scan all git repos under BASE_DIR"
      echo "  --summary PATH          One-line project summary"
      echo "  --compare PATH1 PATH2   Compare security scores"
      echo "  --recommendations PATH  List security improvements"
      echo ""
      echo "Library usage (source this script):"
      echo "  source scripts/project-scanner.sh"
      echo "  scan_project ~/my-app"
      ;;
  esac
fi
