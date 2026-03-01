# Multi-Project Dashboard Integration Guide

Phase 5 enterprise feature for Claude Forge — monitor security, tests, issues, and PRs across all projects.

## Components

### 1. Project Scanner (`scripts/project-scanner.sh`)

Core library for collecting project health metrics.

**Functions:**
- `scan_project(path)` — Scan single project, output JSON
- `scan_all_projects(base_dir)` — Scan all git repos under directory
- `get_project_summary(path)` — One-line summary string
- `compare_security(paths...)` — Compare security scores across projects
- `security_recommendations(path)` — List security improvements

**Metrics Collected:**
- Security score (0-100): Based on CLAUDE.md, .gitignore, hardcoded secrets, SECURITY.md, npm audit
- Test coverage (0-100): Detects Jest, Vitest, Mocha, pytest, go test
- Open issues: Via `gh` CLI (0 if unavailable)
- Pending PRs: Via `gh` CLI (0 if unavailable)
- Last activity: ISO8601 timestamp from git or filesystem

### 2. Dashboard Command (`commands/dashboard.md`)

User-facing command for viewing all projects.

**Usage:**
```bash
/dashboard [--path ~/Projects] [--format table|json]
```

**Output (table format):**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Multi-Project Dashboard
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Project               Security  Tests   Issues   PRs  Last Activity
────────────────────────────────────────────────────────────────────
claude-forge            100/100     0%        7     2       2h ago
my-app                   85/100    92%        3     1       1d ago
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Summary Statistics:
  Total projects:    2
  Avg security:      92/100
  Avg test coverage: 46%
  Total open issues: 10
  Total pending PRs: 3
```

### 3. Dashboard Chip (`scripts/dashboard-chip.sh`)

Lightweight status display for cc-chips integration.

**Output:**
```
[Score: 100 ✓] [Tests: ✗] [Issues: 7] [PRs: 2]
```

**Performance:**
- Reads from cache only (no live scan)
- Executes in under 100ms
- Safe for frequent calls

### 4. Session Start Hook (`hooks/dashboard-scan-hook.sh`)

Auto-scans current project on session start (background, non-blocking).

**Behavior:**
- Triggers on SessionStart event
- Scans current project only (fast)
- Writes to `~/.claude/.dashboard-cache.json`
- Runs in background (`&` + `disown`)
- Always exits 0 (never blocks session)

## Installation

### Step 1: Install Scripts

Scripts are already included in Claude Forge. Ensure they're executable:

```bash
chmod +x ~/.claude/scripts/project-scanner.sh
chmod +x ~/.claude/scripts/dashboard-chip.sh
chmod +x ~/.claude/hooks/dashboard-scan-hook.sh
```

### Step 2: Enable SessionStart Hook

Add to your `~/.config/claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": {
      "hooks": [
        {
          "type": "command",
          "command": "~/.claude/hooks/dashboard-scan-hook.sh",
          "timeout": 5000
        }
      ]
    }
  }
}
```

### Step 3: (Optional) Integrate Dashboard Chip with CC CHIPS

To add project status to your cc-chips status line, modify `~/.claude/cc-chips/engine.sh`:

Add after line 192 (after CHIP 4):

```bash
# CHIP 5: Project dashboard (if available)
DASHBOARD_CHIP=$(bash ~/.claude/scripts/dashboard-chip.sh 2>/dev/null || echo "")
if [ -n "$DASHBOARD_CHIP" ]; then
    printf " "
    printf "${FG_STATS}${CAP_LEFT}${RESET}"
    printf "${BG_STATS}${BOLD}${FG_STATS_TEXT} %s ${RESET}" "$DASHBOARD_CHIP"
    printf "${FG_STATS}${CAP_RIGHT}${RESET}"
fi
```

## Usage Examples

### Scan Single Project

```bash
bash ~/.claude/scripts/project-scanner.sh --scan ~/my-app
```

Output:
```json
{
  "name": "my-app",
  "path": "/Users/you/my-app",
  "last_activity": "2026-03-01T14:30:00+09:00",
  "security_score": 85,
  "test_coverage": 92,
  "open_issues": 3,
  "pending_prs": 1
}
```

### Scan All Projects

```bash
bash ~/.claude/scripts/project-scanner.sh --scan-all ~/Projects
```

### Get Security Recommendations

```bash
bash ~/.claude/scripts/project-scanner.sh --recommendations ~/my-app
```

Output:
```
Add secret patterns to .gitignore (.env, *.pem, etc)
Create SECURITY.md with vulnerability reporting process
Run 'npm audit fix' to patch vulnerabilities
```

### Compare Projects

```bash
bash ~/.claude/scripts/project-scanner.sh --compare ~/app1 ~/app2 ~/app3
```

Output:
```
app2: 95/100 (/Users/you/app2)
app1: 85/100 (/Users/you/app1)
app3: 70/100 (/Users/you/app3)
```

## Cache Structure

Cache file: `~/.claude/.dashboard-cache.json`

```json
[
  {
    "name": "project-name",
    "path": "/absolute/path",
    "last_activity": "2026-03-01T14:30:00+09:00",
    "security_score": 85,
    "test_coverage": 92,
    "open_issues": 3,
    "pending_prs": 1
  }
]
```

## Security Score Breakdown

| Check | Points | Description |
|:------|-------:|:------------|
| CLAUDE.md exists | +10 | Project context documented |
| .gitignore has secret patterns | +15 | .env, *.pem, credentials excluded |
| No hardcoded secrets | +30 | API keys in env vars, not code |
| SECURITY.md exists | +10 | Vulnerability reporting process |
| npm audit clean | +15 | No critical vulnerabilities |
| **Total** | **100** | Perfect security posture |

## Test Coverage Detection

| Framework | File Pattern | Coverage File | Score |
|:----------|:-------------|:--------------|------:|
| Jest | `*.test.js`, `*.spec.js` | `jest.config.js` | 92% |
| Vitest | `*.test.ts`, `*.spec.ts` | `vitest.config.ts` | 92% |
| pytest | `test_*.py` | `.coveragerc` | 88% |
| Go | `*_test.go` | (none) | 82% |

Base score: 75-78% if tests exist without coverage config.

## Performance

| Operation | Time | Notes |
|:----------|-----:|:------|
| Scan single project | ~300ms | Includes gh CLI calls |
| Scan 10 projects | ~3s | Parallel scans possible |
| Dashboard chip read | <100ms | Cache-only, no live scan |
| SessionStart hook | <500ms | Background, non-blocking |

## Troubleshooting

### Chip shows nothing

- Cache file missing: `~/.claude/.dashboard-cache.json`
- Current directory not scanned yet (hook runs on session start)
- Path mismatch (macOS case-sensitivity): Fixed via `ascii_downcase`

### Security score unexpectedly low

Run recommendations:
```bash
bash ~/.claude/scripts/project-scanner.sh --recommendations .
```

### GitHub issues/PRs show 0

Install GitHub CLI:
```bash
brew install gh
gh auth login
```

### Hook not running

Check `~/.config/claude/settings.json` has SessionStart hook registered.

## Future Enhancements

- [ ] Add CI/CD status integration (GitHub Actions, CircleCI)
- [ ] Detect dependency outdatedness (npm outdated, cargo outdated)
- [ ] Track technical debt metrics (TODO comments, FIXME count)
- [ ] Integration with Linear, Jira for issue tracking
- [ ] Real-time notifications for security vulnerabilities
