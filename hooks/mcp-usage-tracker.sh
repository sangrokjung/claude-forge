#!/bin/bash
# MCP Usage Tracker - PreToolUse Hook
# Logs MCP tool calls to ~/.claude/mcp-usage.log
#
# Hook trigger: PreToolUse (all mcp__* tool calls)
# Exit codes: 0 = allow (never blocks)

# Read tool call JSON from stdin
INPUT=$(cat)

echo "$INPUT" | python3 -c "
import sys, json, os
from datetime import datetime, timezone, timedelta

try:
    d = json.load(sys.stdin)
except:
    sys.exit(0)

tool = d.get('tool_name', '')
if not tool.startswith('mcp__'):
    sys.exit(0)

parts = tool.split('__')
server = parts[1] if len(parts) >= 2 else ''
session = d.get('session_id', '') or f'{os.getppid()}'

kst = timezone(timedelta(hours=9))
ts = datetime.now(kst).isoformat()

log = os.path.expanduser('~/.claude/mcp-usage.log')
with open(log, 'a') as f:
    f.write(f'{ts} | {server} | {tool} | {session}\n')
" 2>/dev/null

exit 0
