---
description: 멀티 프로젝트 대시보드를 표시합니다. 보안 점수, 테스트 커버리지, 이슈, PR 상태를 한눈에 확인.
allowed-tools:
  - Bash
  - Read
---

# Multi-Project Dashboard

Display health metrics for all projects under a base directory. Shows security scores, test coverage, open issues, pending PRs, and last activity.

## Usage

```
/dashboard [--path DIR] [--format table|json]
```

## Parameters

| Parameter | Default | Description |
|:----------|:--------|:------------|
| `--path DIR` | `~/Projects` or parent of cwd | Base directory to scan |
| `--format` | table | Output format: `table` or `json` |

## Execution Steps

### Stage 1: Parse Parameters

Parse command arguments and extract options.

```bash
# Default values
SCAN_PATH="$HOME/Projects"
FORMAT="table"

# If cwd is in a parent directory structure, use parent as scan path
CURRENT_DIR=$(pwd)
if [[ "$CURRENT_DIR" != "$HOME" ]] && [[ "$CURRENT_DIR" =~ ^$HOME/[^/]+/[^/]+ ]]; then
  SCAN_PATH=$(dirname "$CURRENT_DIR")
fi

# Parse user arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path)
      SCAN_PATH="$2"
      shift 2
      ;;
    --format)
      FORMAT="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
```

### Stage 2: Scan Projects

Use the `project-scanner.sh` library to scan all git repositories under the base path.

```bash
# Source the scanner library
source ~/.claude/scripts/project-scanner.sh

# Scan all projects
PROJECTS_JSON=$(scan_all_projects "$SCAN_PATH")
```

### Stage 3: Format Output

#### Table Format (default)

Display projects in a formatted table with box-drawing characters.

```bash
if [[ "$FORMAT" == "table" ]]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Multi-Project Dashboard"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Column headers
  printf "%-20s  %8s  %6s  %6s  %4s  %12s\n" \
    "Project" "Security" "Tests" "Issues" "PRs" "Last Activity"

  echo "────────────────────────────────────────────────────────────────────"

  # Parse JSON and display each project
  echo "$PROJECTS_JSON" | jq -r '.[] |
    [.name,
     (.security_score | tostring + "/100"),
     (.test_coverage | tostring + "%"),
     (.open_issues | tostring),
     (.pending_prs | tostring),
     (.last_activity | if . == "" then "never" else . end)
    ] | @tsv' | \
  while IFS=$'\t' read -r name sec tests issues prs activity; do
    # Format activity as relative time
    if [[ "$activity" != "never" ]]; then
      activity_relative=$(python3 -c "
from datetime import datetime, timezone
import sys
try:
    ts = datetime.fromisoformat('$activity'.replace('+00:00', '+0000'))
    now = datetime.now(timezone.utc)
    delta = now - ts.replace(tzinfo=timezone.utc)

    if delta.days > 30:
        print(f'{delta.days // 30}mo ago')
    elif delta.days > 0:
        print(f'{delta.days}d ago')
    elif delta.seconds > 3600:
        print(f'{delta.seconds // 3600}h ago')
    elif delta.seconds > 60:
        print(f'{delta.seconds // 60}m ago')
    else:
        print('just now')
except:
    print('unknown')
" 2>/dev/null || echo "unknown")
    else
      activity_relative="never"
    fi

    printf "%-20s  %8s  %6s  %6s  %4s  %12s\n" \
      "$name" "$sec" "$tests" "$issues" "$prs" "$activity_relative"
  done

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi
```

Expected output:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Multi-Project Dashboard
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Project               Security  Tests   Issues   PRs  Last Activity
────────────────────────────────────────────────────────────────────
my-app                  85/100    92%        3     1       2h ago
api-server              72/100    78%        0     2       1d ago
frontend-v2             90/100    88%        5     0       4h ago
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

#### JSON Format

Output raw JSON for programmatic consumption.

```bash
if [[ "$FORMAT" == "json" ]]; then
  echo "$PROJECTS_JSON" | jq '.'
fi
```

### Stage 4: Display Summary Statistics

After the table, display aggregate statistics.

```bash
TOTAL_PROJECTS=$(echo "$PROJECTS_JSON" | jq 'length')
AVG_SECURITY=$(echo "$PROJECTS_JSON" | jq '[.[].security_score] | add / length | floor')
AVG_TESTS=$(echo "$PROJECTS_JSON" | jq '[.[].test_coverage] | add / length | floor')
TOTAL_ISSUES=$(echo "$PROJECTS_JSON" | jq '[.[].open_issues] | add')
TOTAL_PRS=$(echo "$PROJECTS_JSON" | jq '[.[].pending_prs] | add')

echo ""
echo "Summary Statistics:"
echo "  Total projects:    $TOTAL_PROJECTS"
echo "  Avg security:      $AVG_SECURITY/100"
echo "  Avg test coverage: $AVG_TESTS%"
echo "  Total open issues: $TOTAL_ISSUES"
echo "  Total pending PRs: $TOTAL_PRS"
```

### Stage 5: Security Recommendations (Optional)

If any project has a security score below 70, display recommendations.

```bash
LOW_SECURITY=$(echo "$PROJECTS_JSON" | jq -r '.[] | select(.security_score < 70) | .name')

if [[ -n "$LOW_SECURITY" ]]; then
  echo ""
  echo "⚠️  Projects needing security attention:"

  echo "$LOW_SECURITY" | while read -r project_name; do
    PROJECT_PATH=$(echo "$PROJECTS_JSON" | jq -r ".[] | select(.name == \"$project_name\") | .path")
    echo ""
    echo "  $project_name:"
    security_recommendations "$PROJECT_PATH" | sed 's/^/    - /'
  done
fi
```

## Implementation Notes

- The scanner skips non-git directories automatically
- GitHub integration (`gh` CLI) is optional — if unavailable, issues/PRs show as 0
- Test coverage detection supports: Jest, Vitest, Mocha, pytest, go test
- Security scoring is heuristic-based (file checks, not deep analysis)
- Results are cached to `~/.claude/.dashboard-cache.json` for cc-chips integration

## Performance

- Scanning 10 projects: ~2-3 seconds
- Scanning 50 projects: ~10-15 seconds
- Results are cached for 5 minutes to avoid redundant scans

## Cache Management

After scanning, write results to cache for fast access by cc-chips.

```bash
# Write to cache (atomic)
echo "$PROJECTS_JSON" > "$HOME/.claude/.dashboard-cache.json.tmp"
mv "$HOME/.claude/.dashboard-cache.json.tmp" "$HOME/.claude/.dashboard-cache.json"
```

## Related Commands

| Next steps | Command |
|:-----------|:--------|
| Review specific project | `/security-review --project PATH` |
| Improve test coverage | `/tdd --project PATH` |
| View audit logs | `/audit-report` |

---

## Error Handling

- If `SCAN_PATH` does not exist, display error and suggest creating it
- If no git repos found, display helpful message about initializing projects
- If `jq` is missing, display installation instructions
