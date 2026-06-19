#!/bin/bash
HOOK_GUARD_SKIP_STDIN=1
source "$HOME/.claude/libs/hook-guard.sh"
# context-sync-suggest.sh - SessionStart Hook
# 마지막 세션 종료 후 일정 시간이 경과했으면 /context-sync 안내
# OMC session-start.mjs, project-memory-session.mjs와 독립 공존
# exit 0 필수

INPUT=$(cat)

MSG=$(echo "$INPUT" | $PYTHON3 -c "
import sys, json, os, time
from datetime import datetime, timezone, timedelta

try:
    d = json.load(sys.stdin)
except:
    sys.exit(0)

sid = d.get('session_id', '')
if not sid:
    sys.exit(0)

# buffer.jsonl에서 마지막 session_end 찾기
work_log = os.path.expanduser('~/.claude/work-log/buffer.jsonl')
if not os.path.exists(work_log):
    sys.exit(0)

last_end = None
try:
    with open(work_log, 'r') as f:
        for line in f:
            try:
                ev = json.loads(line.strip())
                if ev.get('event') == 'session_end':
                    last_end = ev.get('ts', '')
            except:
                continue
except:
    sys.exit(0)

if not last_end:
    sys.exit(0)

# 4시간 이상 경과 시 제안
try:
    last_dt = datetime.fromisoformat(last_end)
    now = datetime.now(timezone(timedelta(hours=9)))
    gap_hours = (now - last_dt).total_seconds() / 3600
    if gap_hours < 4:
        sys.exit(0)
except:
    sys.exit(0)

gap_display = f'{int(gap_hours)}시간' if gap_hours < 48 else f'{int(gap_hours/24)}일'
print(f'[Context Sync] 마지막 세션 이후 {gap_display} 경과. /context-sync로 놓친 활동을 확인하세요.')
" 2>/dev/null)

# 첫 사용자 감지: .forge-onboarded 마커 없으면 /guide 안내
if [[ ! -f "$HOME/.claude/.forge-onboarded" ]]; then
    if [[ -n "$MSG" ]]; then
        MSG="$MSG
[Claude Forge] 처음이신가요? /guide 로 시작해보세요."
    else
        MSG="[Claude Forge] 처음이신가요? /guide 로 시작해보세요."
    fi
fi

if [[ -n "$MSG" ]]; then
    $PYTHON3 -c "
import json, sys
msg = sys.argv[1]
output = {'hookSpecificOutput': {'hookEventName': 'SessionStart', 'additionalContext': msg}}
print(json.dumps(output, ensure_ascii=False))
" "$MSG" 2>/dev/null
fi

exit 0
