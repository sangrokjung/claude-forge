#!/bin/bash
# audit-log-hook.sh — PostToolUse audit logging hook
# Records every tool use event to structured audit logs.
#
# Hook trigger: PostToolUse (all tool calls)
# Timeout: 5000ms
# Exit codes: 0 always (never blocks session)
#
# Registration (add to settings.json PostToolUse hooks):
#   {
#     "hooks": [
#       {
#         "type": "command",
#         "command": "~/.claude/hooks/audit-log-hook.sh",
#         "timeout": 5000
#       }
#     ]
#   }

INPUT=$(cat)

echo "$INPUT" | python3 -c "
import sys, json, os, socket
from datetime import datetime, timezone, timedelta

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

session_id = d.get('session_id', '')
tool_name = d.get('tool_name', '')
if not tool_name:
    sys.exit(0)

# Extract tool input details (sanitized)
tool_input = d.get('tool_input', {})
tool_result = d.get('tool_result', '')

# Determine action category
ACTION_MAP = {
    'Bash': 'command',
    'Read': 'tool',
    'Write': 'tool',
    'Edit': 'tool',
    'Glob': 'tool',
    'Grep': 'tool',
    'NotebookEdit': 'tool',
    'WebSearch': 'tool',
    'Task': 'agent',
    'SendMessage': 'agent',
    'TaskCreate': 'agent',
    'TaskUpdate': 'agent',
    'Skill': 'tool',
}

action = 'tool'
if tool_name in ACTION_MAP:
    action = ACTION_MAP[tool_name]
elif tool_name.startswith('mcp__'):
    action = 'tool'

# Build metadata (limit size to prevent bloated logs)
metadata = {
    'session_id': session_id,
    'tool_name': tool_name,
}

# For Bash, capture the command (truncated)
if tool_name == 'Bash':
    cmd = tool_input.get('command', '')
    metadata['command'] = cmd[:500] if cmd else ''

# For file operations, capture file path
file_path = tool_input.get('file_path', '')
if file_path:
    metadata['file_path'] = file_path

# Determine result status
result_status = 'success'
if isinstance(tool_result, str) and ('error' in tool_result.lower() or 'fail' in tool_result.lower()):
    result_status = 'failure'

# Build the audit entry
kst = timezone(timedelta(hours=9))
ts = datetime.now(kst).strftime('%Y-%m-%dT%H:%M:%S%z')
user = os.environ.get('USER', 'unknown')

# Get git branch
branch = ''
try:
    import subprocess
    branch = subprocess.check_output(
        ['git', 'branch', '--show-current'],
        stderr=subprocess.DEVNULL, timeout=2
    ).decode().strip()
except Exception:
    pass

entry = {
    'timestamp': ts,
    'user': user,
    'action': action,
    'target': tool_name,
    'result': result_status,
    'metadata': {
        **metadata,
        'branch': branch,
    }
}

# Write to daily audit log
audit_dir = os.path.expanduser('~/.claude/audit')
os.makedirs(audit_dir, exist_ok=True)

date_str = datetime.now(kst).strftime('%Y-%m-%d')
log_file = os.path.join(audit_dir, f'{date_str}.jsonl')

with open(log_file, 'a') as f:
    f.write(json.dumps(entry, ensure_ascii=False) + '\n')

# Check for security-relevant tools and log separately
SECURITY_TOOLS = {'Write', 'Edit', 'Bash', 'NotebookEdit'}
security_patterns = ['password', 'secret', 'token', 'key', 'credential', 'auth']

is_security_relevant = False
if tool_name in SECURITY_TOOLS:
    check_str = json.dumps(tool_input).lower()
    for pattern in security_patterns:
        if pattern in check_str:
            is_security_relevant = True
            break

if is_security_relevant:
    sec_dir = os.path.join(audit_dir, 'security')
    os.makedirs(sec_dir, exist_ok=True)
    sec_file = os.path.join(sec_dir, f'{date_str}.jsonl')
    sec_entry = {
        'timestamp': ts,
        'user': user,
        'event_type': 'security_relevant_tool_use',
        'severity': 'security',
        'details': {
            'tool_name': tool_name,
            'file_path': file_path,
            'session_id': session_id,
            'branch': branch,
        }
    }
    with open(sec_file, 'a') as f:
        f.write(json.dumps(sec_entry, ensure_ascii=False) + '\n')

" 2>/dev/null

exit 0
