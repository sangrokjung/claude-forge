#!/bin/bash
# work-tracker-install.sh
# Claude Code 업무 추적 시스템 설치 (다른 PC에서도 실행 가능)
# 사용: bash dotclaude/setup/work-tracker-install.sh
#       또는 install.sh에서 자동 호출

set -e

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"
CLAUDE_DIR="$HOME/.claude"
LAUNCH_AGENTS="$HOME/Library/LaunchAgents"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "Work Tracker 설치"
echo "================="

# work-tracker-sync.sh는 **선택 구성요소**다. 동기화 대상(백엔드)이 사용자마다 달라
# claude-forge는 이 스크립트를 배포하지 않는다. 없어도 훅 3종이
# ~/.claude/work-log/buffer.jsonl에 로컬 기록을 계속하므로 추적 자체는 동작한다.
# (#6: 예전에는 이 파일이 없으면 `set -e` + `return 1`로 설치 전체가 중단됐다.)
SYNC_SRC="$REPO_DIR/scripts/work-tracker-sync.sh"
HAS_SYNC=0
[ -f "$SYNC_SRC" ] && HAS_SYNC=1

# 0. 이미 설치 완료 확인 (빠른 스킵)
quick_check() {
    [ -d "$CLAUDE_DIR/work-log" ] && \
    [ -f "$CLAUDE_DIR/hooks/work-tracker-prompt.sh" ] && \
    { [ "$HAS_SYNC" -eq 0 ] || [ -f "$CLAUDE_DIR/scripts/work-tracker-sync.sh" ]; } && \
    { [ "$HAS_SYNC" -eq 0 ] || [[ "$OSTYPE" != "darwin"* ]] || launchctl list 2>/dev/null | grep -q "work-tracker"; }
}

if quick_check; then
    # sync 스크립트 버전 비교 (업데이트 필요 시에만 재설치)
    if [ "$HAS_SYNC" -eq 0 ] || diff -q "$SYNC_SRC" "$CLAUDE_DIR/scripts/work-tracker-sync.sh" >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Work Tracker 이미 설치됨 (최신)"
        return 0 2>/dev/null || exit 0
    else
        echo -e "  ${YELLOW}!${NC} Work Tracker 업데이트 감지 — 재설치..."
    fi
fi

# 1. work-log 디렉토리 생성
setup_worklog_dir() {
    echo "  work-log 디렉토리 생성..."
    mkdir -p "$CLAUDE_DIR/work-log/.sessions"
    mkdir -p "$CLAUDE_DIR/work-log/archive"
    touch "$CLAUDE_DIR/work-log/buffer.jsonl"
    echo -e "  ${GREEN}✓${NC} ~/.claude/work-log/"
}

# 2. sync 스크립트 복사
install_sync_script() {
    echo "  sync 스크립트 설치..."
    local src="$SYNC_SRC"
    local dst="$CLAUDE_DIR/scripts/work-tracker-sync.sh"

    if [ "$HAS_SYNC" -eq 0 ]; then
        echo -e "  ${YELLOW}!${NC} 원격 동기화 생략 (선택 구성요소, 로컬 기록은 정상 동작)"
        echo "    필요하면 scripts/work-tracker-sync.sh를 직접 두고 다시 실행하세요."
        return 0
    fi

    mkdir -p "$CLAUDE_DIR/scripts"
    cp "$src" "$dst"
    chmod +x "$dst"
    echo -e "  ${GREEN}✓${NC} ~/.claude/scripts/work-tracker-sync.sh"
}

# 3. LaunchAgent 설치 (macOS only)
install_launchagent() {
    # sync 스크립트가 없으면 타이머를 걸지 않는다. 걸어두면 1분마다 없는 파일을 실행하려다
    # 실패하는 LaunchAgent가 남아, 설치가 "성공"한 것처럼 보이면서 로그만 더럽힌다.
    if [ "$HAS_SYNC" -eq 0 ]; then
        echo -e "  ${YELLOW}!${NC} LaunchAgent 건너뜀 (동기화할 sync 스크립트 없음)"
        return 0
    fi

    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "  ${YELLOW}!${NC} macOS가 아님 — LaunchAgent 건너뜀 (cron 수동 설정 필요)"
        return 0
    fi

    echo "  LaunchAgent 설치..."
    local plist_name="com.claude.work-tracker-sync.plist"
    local dst="$LAUNCH_AGENTS/$plist_name"

    # 기존 LaunchAgent 언로드 (있으면)
    launchctl unload "$dst" 2>/dev/null || true

    # SUPABASE_ANON_KEY 확인
    local anon_key=""
    if [ -f "$CLAUDE_DIR/settings.json" ] && command -v python3 >/dev/null; then
        anon_key=$(python3 -c "
import json, sys
try:
    d = json.load(open('$CLAUDE_DIR/settings.json'))
    print(d.get('env', {}).get('SUPABASE_ANON_KEY', ''))
except: pass
" 2>/dev/null)
    fi

    if [ -z "$anon_key" ]; then
        echo -e "  ${YELLOW}!${NC} SUPABASE_ANON_KEY 미발견 — settings.json env 확인 필요"
        echo "  settings.json의 env에 SUPABASE_ANON_KEY를 추가한 뒤 이 스크립트를 다시 실행하세요."
        echo -e "  ${YELLOW}!${NC} LaunchAgent 설치 건너뜀 (나머지 설치는 정상 진행)"
        return 0
    fi

    # plist 생성 (경로를 현재 사용자 HOME으로 치환)
    mkdir -p "$LAUNCH_AGENTS"
    cat > "$dst" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.work-tracker-sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>${HOME}/.claude/scripts/work-tracker-sync.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>60</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>SUPABASE_ANON_KEY</key>
        <string>${anon_key}</string>
    </dict>
    <key>StandardOutPath</key>
    <string>${HOME}/.claude/work-log/sync-stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/.claude/work-log/sync-stderr.log</string>
</dict>
</plist>
PLIST

    # 로드
    launchctl load "$dst"
    echo -e "  ${GREEN}✓${NC} LaunchAgent 등록 (1분 주기)"
}

# 4. 검증
verify_install() {
    echo ""
    echo "  검증 중..."
    local errors=0

    # 훅 파일 확인 (심링크 통해 이미 존재해야 함)
    for hook in work-tracker-prompt.sh work-tracker-tool.sh work-tracker-stop.sh; do
        if [ -f "$CLAUDE_DIR/hooks/$hook" ] && [ -x "$CLAUDE_DIR/hooks/$hook" ]; then
            echo -e "  ${GREEN}✓${NC} hooks/$hook"
        else
            echo -e "  ${RED}✗${NC} hooks/$hook (없거나 실행권한 없음)"
            errors=$((errors + 1))
        fi
    done

    # sync 스크립트 (선택 구성요소 — 미배포 상태는 실패가 아니다)
    if [ -f "$CLAUDE_DIR/scripts/work-tracker-sync.sh" ] && [ -x "$CLAUDE_DIR/scripts/work-tracker-sync.sh" ]; then
        echo -e "  ${GREEN}✓${NC} scripts/work-tracker-sync.sh"
    elif [ "$HAS_SYNC" -eq 0 ]; then
        echo -e "  ${YELLOW}!${NC} scripts/work-tracker-sync.sh (선택 — 원격 동기화 미사용)"
    else
        echo -e "  ${RED}✗${NC} scripts/work-tracker-sync.sh"
        errors=$((errors + 1))
    fi

    # work-log 디렉토리
    if [ -d "$CLAUDE_DIR/work-log" ]; then
        echo -e "  ${GREEN}✓${NC} work-log/"
    else
        echo -e "  ${RED}✗${NC} work-log/"
        errors=$((errors + 1))
    fi

    # settings.json에 hooks 이벤트 확인
    if command -v python3 >/dev/null && [ -f "$CLAUDE_DIR/settings.json" ]; then
        local has_hooks=$(python3 -c "
import json
d = json.load(open('$CLAUDE_DIR/settings.json'))
hooks = d.get('hooks', {})
events = ['UserPromptSubmit', 'PostToolUse', 'Stop']
print('ok' if all(e in hooks for e in events) else 'missing')
" 2>/dev/null)
        if [ "$has_hooks" = "ok" ]; then
            echo -e "  ${GREEN}✓${NC} settings.json hooks (3개 이벤트)"
        else
            echo -e "  ${RED}✗${NC} settings.json hooks (UserPromptSubmit/PostToolUse/Stop 누락)"
            errors=$((errors + 1))
        fi
    fi

    # LaunchAgent (macOS). sync를 설치하지 않았으면 이 설치와 무관하므로 보고하지 않는다
    # (남아 있는 다른 work-tracker 항목을 "이번 설치 결과"로 오인하게 만든다).
    if [[ "$OSTYPE" == "darwin"* ]] && [ "$HAS_SYNC" -eq 1 ]; then
        if launchctl list 2>/dev/null | grep -q "work-tracker"; then
            echo -e "  ${GREEN}✓${NC} LaunchAgent 실행 중"
        else
            echo -e "  ${YELLOW}!${NC} LaunchAgent 미실행"
        fi
    fi

    echo ""
    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}Work Tracker 설치 완료!${NC}"
    else
        echo -e "${RED}${errors}개 항목 확인 필요${NC}"
    fi
    return $errors
}

# Main
setup_worklog_dir
install_sync_script
install_launchagent
verify_install
