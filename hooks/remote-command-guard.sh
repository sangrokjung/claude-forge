#!/bin/bash
# Remote Command Guard - PreToolUse Hook
# 원격 Claude Code 세션에서 위험한 Bash 명령을 차단
#
# Hook trigger: PreToolUse, matcher: Bash
# Exit codes: 0 = 허용, 2 = 차단
#
# 차단 범주:
#   1. 파괴적 삭제 (rm -rf /, rm -rf ~, rm -rf *)
#   2. 환경변수/시크릿 유출 (env, printenv, echo $SECRET 등)
#   3. 경로 순회 (/etc/passwd, /etc/shadow 등)
#   4. 외부 통신 (curl, wget, nc, ncat 등)
#   5. 권한 변경 (chmod 777, chown, mount 등)
#   6. 프로세스 종료 (kill -9, pkill 등)
#   7. 명령 주입 (eval, exec 등)

# 원격 세션이 아니면 검사 건너뜀
if [[ -z "${OPENCLAW_SESSION_ID:-}" ]]; then
    exit 0
fi

# stdin에서 JSON 읽기
INPUT=$(cat)

# 명령어 추출 (python3 -c + 작은따옴표로 셸 확장 방지)
COMMAND=$(echo "$INPUT" | python3 -c '
import sys, json
data = json.load(sys.stdin)
print(data.get("tool_input", {}).get("command", ""))
' 2>/dev/null)

if [[ -z "$COMMAND" ]]; then
    exit 0
fi

# 환경변수로 명령어 전달 → heredoc으로 Python 검사 로직 주입
export _GUARD_CMD="$COMMAND"
python3 << 'GUARD_SCRIPT'
import os
import sys
import re

command = os.environ.get("_GUARD_CMD", "")
if not command:
    sys.exit(0)

# 명령어 정규화 (여러 공백 → 단일 공백)
cmd = re.sub(r'\s+', ' ', command.strip())
cmd_lower = cmd.lower()

blocked_reason = None

# === 1. 파괴적 삭제 ===
# rm -rf / , rm -rf ~ , rm -rf * 등 광범위 삭제만 차단
# rm /tmp/specific-file.txt 같은 특정 파일 삭제는 허용
destructive_patterns = [
    r'\brm\s+-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*\s',  # rm -rf, rm -rfi 등
    r'\brm\s+-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*\s',  # rm -fr, rm -fri 등
    r'\brm\b.*\s+/$',                              # rm / (루트)
    r'\brm\b.*\s+/\s',                             # rm / something
    r'\brm\b.*\s+~/?(\s|$)',                        # rm ~ 또는 rm ~/
    r'\brm\b.*\s+\*(\s|$)',                         # rm * (현재 디렉토리 전체)
    r'\bmkfs\b',
    r'\bdd\s+.*of=/dev/',
    r'\b:\s*\(\)\s*\{\s*:\s*\|\s*:\s*&\s*\}\s*;',
]
for pat in destructive_patterns:
    if re.search(pat, cmd_lower):
        blocked_reason = "파괴적 삭제 명령 감지"
        break

# === 2. 환경변수/시크릿 유출 ===
# 시크릿 패턴은 원본 cmd에 re.IGNORECASE로 매칭 (환경변수명 대소문자 보존)
if not blocked_reason:
    secret_patterns = [
        r'\b(env|printenv|set)\s*$',
        r'\b(env|printenv|set)\s*\|',
        r'\becho\s+.*\$[A-Z_]*KEY\b',
        r'\becho\s+.*\$[A-Z_]*SECRET\b',
        r'\becho\s+.*\$[A-Z_]*TOKEN\b',
        r'\becho\s+.*\$[A-Z_]*PASSWORD\b',
        r'\becho\s+.*\$[A-Z_]*PASSWD\b',
        r'\becho\s+.*\$[A-Z_]*API\b',
        r'\becho\s+.*\$[A-Z_]*CREDENTIAL\b',
        r'\becho\s+.*\$(AWS_|OPENAI_|ANTHROPIC_|TELEGRAM_|GITHUB_|SUPABASE_)',
        r'\bcat\s+.*\.env\b',
        r'\bcat\s+.*\.netrc\b',
        r'\bcat\s+.*credentials\b',
        r'\bcat\s+.*/\.ssh/',
        r'\bexport\s+-p\s*$',
        r'\bexport\s+-p\s*\|',
        r'\bcat\s+.*seed\.txt\b',
        r'\bcat\s+.*wallet\.json\b',
        r'\bcat\s+.*keystore\b',
    ]
    for pat in secret_patterns:
        if re.search(pat, cmd, re.IGNORECASE):
            blocked_reason = "시크릿/환경변수 유출 시도 감지"
            break

# === 3. 경로 순회 ===
if not blocked_reason:
    path_traversal_patterns = [
        r'/etc/passwd',
        r'/etc/shadow',
        r'/etc/sudoers',
        r'/etc/master\.passwd',
        r'\.\./(\.\./)*(etc|proc|sys|dev)/',
        r'/proc/self/',
        r'/proc/\d+/',
        r'/sys/class/',
    ]
    for pat in path_traversal_patterns:
        if re.search(pat, cmd_lower):
            blocked_reason = "민감 시스템 경로 접근 감지"
            break

# === 4. 외부 통신 ===
if not blocked_reason:
    network_patterns = [
        r'\bcurl\s',
        r'\bwget\s',
        r'\bnc\s',
        r'\bncat\s',
        r'\bnetcat\s',
        r'\btelnet\s',
        r'\bssh\s',
        r'\bscp\s',
        r'\brsync\s.*:',
        r'\bftp\s',
        r'\bsftp\s',
        r'\bsocat\s',
        r'\bpython3?\s+-m\s+http\.server',
        r'\bphp\s+-S\s',
        r'\bnpm\s+publish\b',
        r'\bnpx\s.*ngrok',
    ]
    # localhost/127.0.0.1 대상 curl/wget은 허용 (개발용)
    is_local = bool(re.search(
        r'\bcurl\s+.*\b(localhost|127\.0\.0\.1|0\.0\.0\.0)\b', cmd_lower
    ))
    if not is_local:
        for pat in network_patterns:
            if re.search(pat, cmd_lower):
                blocked_reason = "외부 네트워크 통신 시도 감지"
                break

# === 5. 권한 변경 ===
if not blocked_reason:
    permission_patterns = [
        r'\bchmod\s+777\b',
        r'\bchmod\s+666\b',
        r'\bchmod\s+[0-7]*[67][0-7]{2}\b.*/(etc|usr|var|sys)',
        r'\bchown\s',
        r'\bmount\s',
        r'\bumount\s',
        r'\bsudo\s',
        r'\bsu\s+-?\s',
        r'\bdscl\s',
    ]
    for pat in permission_patterns:
        if re.search(pat, cmd_lower):
            blocked_reason = "권한 변경 명령 감지"
            break

# === 6. 프로세스 종료 ===
if not blocked_reason:
    process_patterns = [
        r'\bkill\s+-9\b',
        r'\bkill\s+-KILL\b',
        r'\bkill\s+-SIGKILL\b',
        r'\bkillall\s',
        r'\bpkill\s',
        r'\bxkill\b',
        r'\bshutdown\b',
        r'\breboot\b',
        r'\bhalt\b',
        r'\binit\s+[06]\b',
    ]
    for pat in process_patterns:
        if re.search(pat, cmd_lower):
            blocked_reason = "프로세스 종료/시스템 제어 명령 감지"
            break

# === 7. 명령 주입 ===
if not blocked_reason:
    injection_patterns = [
        r'\beval\s',
        r'\bexec\s',
        r'\bsource\s+/dev/',
        r'\bbash\s+-c\s.*\$\(',
        r'\bsh\s+-c\s.*\$\(',
        r'`[^`]*\$\([^)]+\)[^`]*`',
        r'\|\s*sh\b',
        r'\|\s*bash\b',
        r'\|\s*zsh\b',
        r'>\s*/dev/sd[a-z]',
        r'>\s*/dev/nvme',
        r'\bbase64\s+-d\s*\|\s*(sh|bash|zsh)',
    ]
    for pat in injection_patterns:
        if re.search(pat, cmd_lower):
            blocked_reason = "명령 주입 패턴 감지"
            break

if blocked_reason:
    safe_cmd = cmd[:200]
    print(f"BLOCKED: {blocked_reason}", file=sys.stderr)
    print(f"Command: {safe_cmd}", file=sys.stderr)
    sys.exit(2)

sys.exit(0)
GUARD_SCRIPT
