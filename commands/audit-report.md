---
description: 감사 로그 리포트를 생성합니다. 기간/유형/형식 지정 가능.
---

# Audit Report

Generate an audit log report with filtering and formatting options.

## Usage

```
/audit-report [--days N] [--type security|all] [--format table|json|csv]
```

## Parameters

| Parameter | Default | Description |
|:----------|:--------|:------------|
| `--days N` | 7 | Report period in days |
| `--type` | all | Event type filter: `all` or `security` |
| `--format` | table | Output format: `table`, `json`, or `csv` |

## Execution Steps

### Stage 1: Parse Parameters

Parse the user's command arguments. Extract `--days`, `--type`, and `--format` values. Use defaults for any missing parameters.

### Stage 2: Collect Audit Data

Read audit log files from `~/.claude/audit/` (or `~/.claude/audit/security/` for security type).

```bash
# Find log files within the date range
AUDIT_DIR="$HOME/.claude/audit"
SECURITY_DIR="$HOME/.claude/audit/security"

# List files modified within --days
find "$AUDIT_DIR" -maxdepth 1 -name "*.jsonl" -type f -mtime -${DAYS}
```

### Stage 3: Generate Summary Statistics

Calculate and display:
- **Total events**: Count of all audit entries in the period
- **Security events**: Count of security-specific entries
- **Top 5 actions**: Most frequently executed tool/command targets
- **Active sessions**: Unique session IDs in the period
- **Failure rate**: Percentage of failed operations

### Stage 4: Format Output

#### Table Format (default)

```
=== Audit Report (Last 7 days) ===

Summary:
  Total events:    1,234
  Security events: 23
  Active sessions: 5
  Failure rate:    2.1%

Top 5 Actions:
  Rank  Action          Count
  1     Bash            456
  2     Edit            321
  3     Read            234
  4     Write           123
  5     Grep            100

Recent Security Events:
  Timestamp            Event Type                 File
  2026-02-28 14:32:01  security_relevant_tool_use auth.ts
  2026-02-28 10:15:44  secret_detected            .env.local
```

#### JSON Format

```json
{
  "period_days": 7,
  "total_events": 1234,
  "security_events": 23,
  "active_sessions": 5,
  "failure_rate": "2.1%",
  "top_actions": [
    {"action": "Bash", "count": 456},
    {"action": "Edit", "count": 321}
  ],
  "recent_security": [...]
}
```

#### CSV Format

```csv
timestamp,user,action,target,result
2026-02-28T14:32:01+0900,kyuhong,tool,Bash,success
2026-02-28T14:31:55+0900,kyuhong,tool,Edit,success
```

### Stage 5: Display Results

Output the formatted report to the user. If no audit data exists, display a helpful message explaining how to enable audit logging.

## Implementation Notes

- Use `jq` for all JSON processing
- Handle missing log files gracefully (empty period = zero counts)
- Security events are in `~/.claude/audit/security/` directory
- All events are in `~/.claude/audit/` directory
- Log format: JSON-lines (.jsonl), one JSON object per line

## Enabling Audit Logging

To enable audit logging, add the hook to your settings.json `PostToolUse` section:

```json
{
  "hooks": [{
    "type": "command",
    "command": "~/.claude/hooks/audit-log-hook.sh",
    "timeout": 5000
  }]
}
```

Or source the library in your own scripts:

```bash
source scripts/audit-logger.sh
log_audit "tool" "MyTool" "success" '{"key":"value"}'
```

---

## Related Commands

| After reporting | Command |
|:----------------|:--------|
| Export raw data | `bash scripts/audit-export.sh --format csv --days 30` |
| Security review | `/security-review` |
| Session summary | `/checkpoint` |
