#!/bin/bash
# work-tracker-prompt.sh - UserPromptSubmit Hook
# 세션 시작/프롬프트 이벤트를 buffer.jsonl에 기록
# [C2 fix] eval 제거 → Python에서 전체 로직 처리 (인젝션 방지)
# exit 0 필수 (세션 방해 금지)

INPUT=$(cat)
BUFFER="$HOME/.claude/work-log/buffer.jsonl"
SESSIONS_DIR="$HOME/.claude/work-log/.sessions"

echo "$INPUT" | python3 -c "
import sys, json, os, socket
from datetime import datetime, timezone, timedelta

try:
    d = json.load(sys.stdin)
except:
    sys.exit(0)

sid = d.get('session_id', '')
if not sid:
    sys.exit(0)

cwd = d.get('cwd', '')
prompt = d.get('prompt', '')[:500].replace('\n', ' ')
hostname = socket.gethostname().split('.')[0]
kst = timezone(timedelta(hours=9))
ts = datetime.now(kst).isoformat()

sessions_dir = os.path.expanduser('~/.claude/work-log/.sessions')
os.makedirs(sessions_dir, exist_ok=True)
marker = os.path.join(sessions_dir, sid)
buffer = os.path.expanduser('~/.claude/work-log/buffer.jsonl')

if not os.path.exists(marker):
    project_name = os.path.basename(cwd) if cwd else ''
    open(marker, 'w').close()
    rec = {
        'event': 'session_start',
        'session_id': sid,
        'hostname': hostname,
        'cwd': cwd,
        'project_name': project_name,
        'prompt': prompt,
        'ts': ts
    }
else:
    rec = {
        'event': 'prompt',
        'session_id': sid,
        'hostname': hostname,
        'prompt': prompt,
        'ts': ts
    }

import fcntl
with open(buffer, 'a') as f:
    fcntl.flock(f, fcntl.LOCK_EX)
    f.write(json.dumps(rec, ensure_ascii=False) + '\n')
    f.flush()
    fcntl.flock(f, fcntl.LOCK_UN)
" 2>/dev/null

exit 0
