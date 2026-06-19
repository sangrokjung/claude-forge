#!/bin/bash
set -e

#
# Mac Server Headless Setup Script
# Mac을 Claude Code 원격 개발 서버로 설정합니다.
#
# 사용법: ./setup-mac-server.sh [--hostname NAME] [--skip-tailscale] [--dry-run]
#

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

HOSTNAME=""
SKIP_TAILSCALE=false
DRY_RUN=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --hostname) HOSTNAME="$2"; shift ;;
        --skip-tailscale) SKIP_TAILSCALE=true ;;
        --dry-run) DRY_RUN=true ;;
        *) echo "알 수 없는 옵션: $1"; exit 1 ;;
    esac
    shift
done

# --dry-run 모드: 실제 변경 없이 예정 작업만 출력
if [[ "$DRY_RUN" == true ]]; then
    echo -e "${BLUE}[DRY-RUN] 실제 변경 없이 예정 작업만 출력합니다.${NC}"
    echo ""
    echo "수행 예정 작업:"
    echo "  1. 슬립(절전) 비활성화"
    echo "  2. 원격 접속(SSH) 활성화"
    echo "  3. 개발 도구 설치 (Homebrew, Node.js, Claude Code)"
    if [[ "$SKIP_TAILSCALE" != true ]]; then
        echo "  4. VPN(Tailscale) 설치"
    else
        echo "  4. VPN(Tailscale) 건너뜀 (--skip-tailscale)"
    fi
    echo "  5. 세션 유지 도구(tmux) 설정"
    echo "  6. 방화벽 설정"
    echo "  7. Claude Code 설정 파일 설치"
    echo "  8. 팀원 SSH 키 등록"
    echo "  9. 비밀번호 접속 차단 (안전 확인 후)"
    if [[ -n "$HOSTNAME" ]]; then
        echo ""
        echo "  호스트명 설정: $HOSTNAME"
    fi
    echo ""
    echo -e "${YELLOW}실제 실행하려면 --dry-run 없이 다시 실행하세요.${NC}"
    exit 0
fi

# 시작 안내
echo -e "${BLUE}Mac 서버 설정 스크립트 (Claude Code)${NC}"
echo "======================================"
echo ""
echo "이 스크립트는 Mac을 원격 개발 서버로 설정합니다."
echo ""
echo "수행 작업:"
echo "  1. 슬립(절전) 비활성화"
echo "  2. 원격 접속(SSH) 활성화"
echo "  3. 개발 도구 설치 (Homebrew, Node.js, Claude Code)"
echo "  4. VPN(Tailscale) 설치"
echo "  5. 세션 유지 도구(tmux) 설정"
echo "  6. 방화벽 설정"
echo "  7. Claude Code 설정 파일 설치"
echo "  8. 팀원 SSH 키 등록"
echo "  9. 비밀번호 접속 차단 (안전 확인 후)"
echo ""
echo "예상 소요 시간: 약 20-30분"
echo "관리자 비밀번호가 필요합니다."
echo ""

read -r -p "계속 진행할까요? (y/n): " reply
if [[ "$reply" != "y" && "$reply" != "Y" ]]; then
    echo "취소되었습니다."
    exit 0
fi
echo ""

# 사용자 확인 프롬프트 함수
confirm_step() {
    local message="$1"
    read -r -p "$message (y/n): " reply
    if [[ "$reply" != "y" && "$reply" != "Y" ]]; then
        echo -e "  ${YELLOW}건너뜀${NC}"
        return 1
    fi
    return 0
}

# --------------------------------------------------
# 1. 시스템 설정 (호스트명, 절전 비활성화, 자동 재시작)
# --------------------------------------------------
setup_system() {
    echo -e "${BLUE}[1/9] 시스템 설정...${NC}"

    # 호스트명 변경
    if [[ -n "$HOSTNAME" ]]; then
        echo "  호스트명을 '$HOSTNAME'(으)로 설정합니다..."
        sudo scutil --set ComputerName "$HOSTNAME"
        sudo scutil --set HostName "$HOSTNAME"
        sudo scutil --set LocalHostName "$HOSTNAME"
        echo -e "  ${GREEN}OK${NC} 호스트명 설정 완료"
    fi

    # 슬립 비활성화 전 확인
    if confirm_step "  Mac이 절전 모드에 들어가지 않습니다. 계속할까요?"; then
        echo "  슬립(절전) 비활성화 중..."
        sudo pmset -a sleep 0
        sudo pmset -a displaysleep 0
        sudo pmset -a disksleep 0
        sudo pmset -a hibernatemode 0
        sudo pmset -a autopoweroff 0
        echo -e "  ${GREEN}OK${NC} 절전 비활성화 완료"
    fi

    # 정전 후 자동 재시작
    echo "  정전 후 자동 재시작 설정 중..."
    sudo pmset -a autorestart 1
    echo -e "  ${GREEN}OK${NC} 자동 재시작 설정 완료"

    # 자동 로그인 안내
    echo "  자동 로그인은 수동 설정이 필요합니다."
    echo -e "  ${YELLOW}!${NC} 시스템 설정 > 사용자 및 그룹 > 자동 로그인에서 설정하세요"
}

# --------------------------------------------------
# 2. 원격 접속(SSH) 활성화 (비밀번호 인증은 유지)
# --------------------------------------------------
setup_ssh() {
    echo ""
    echo -e "${BLUE}[2/9] SSH(원격 접속) 설정...${NC}"

    # SSH 서비스 활성화
    echo "  원격 로그인(SSH) 활성화 중..."
    sudo systemsetup -setremotelogin on 2>/dev/null || \
        echo -e "  ${YELLOW}!${NC} 수동 설정 필요: 시스템 설정 > 일반 > 공유 > 원격 로그인 켜기"

    # SSH 호스트 키 생성
    echo "  SSH 호스트 키 확인 중..."
    if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
        sudo ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
        echo -e "  ${GREEN}OK${NC} 호스트 키 생성 완료"
    else
        echo -e "  ${GREEN}OK${NC} 호스트 키 이미 존재"
    fi

    # authorized_keys 파일 준비 (비밀번호 인증은 아직 유지)
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    touch "$HOME/.ssh/authorized_keys"
    chmod 600 "$HOME/.ssh/authorized_keys"
    echo -e "  ${GREEN}OK${NC} SSH 설정 완료 (비밀번호 인증 유지 중)"
}

# --------------------------------------------------
# 3. 개발 도구 설치 (Homebrew, Node.js, Claude Code)
# --------------------------------------------------
install_tools() {
    echo ""
    echo -e "${BLUE}[3/9] 개발 도구 설치...${NC}"

    # Homebrew 설치
    if ! command -v brew >/dev/null 2>&1; then
        echo "  Homebrew 설치 중..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)"
        echo -e "  ${GREEN}OK${NC} Homebrew 설치 완료"
    else
        echo -e "  ${GREEN}OK${NC} Homebrew 이미 설치됨"
    fi

    # 핵심 패키지 설치 (Node.js, jq, tmux, htop)
    echo "  핵심 패키지 설치 중 (Node.js, jq, tmux, htop)..."
    brew install node@22 jq tmux htop 2>/dev/null || true
    echo -e "  ${GREEN}OK${NC} 핵심 패키지 설치 완료"

    # Claude Code 설치
    echo "  Claude Code 설치 중..."
    if command -v claude >/dev/null 2>&1; then
        echo -e "  ${GREEN}OK${NC} Claude Code 이미 설치됨"
    else
        npm install -g @anthropic-ai/claude-code 2>/dev/null || \
            echo -e "  ${YELLOW}!${NC} 수동 설치 필요: npm install -g @anthropic-ai/claude-code"
    fi
}

# --------------------------------------------------
# 4. VPN(Tailscale) 설치
# --------------------------------------------------
install_tailscale() {
    echo ""
    echo -e "${BLUE}[4/9] Tailscale(VPN) 설정...${NC}"

    if [[ "$SKIP_TAILSCALE" == true ]]; then
        echo -e "  ${YELLOW}!${NC} 건너뜀 (--skip-tailscale 옵션)"
        return 0
    fi

    # Tailscale 설치
    if command -v tailscale >/dev/null 2>&1; then
        echo -e "  ${GREEN}OK${NC} Tailscale 이미 설치됨"
    else
        echo "  Tailscale 설치 중..."
        brew install --cask tailscale 2>/dev/null || \
            echo -e "  ${YELLOW}!${NC} 수동 설치: https://tailscale.com/download/mac"
    fi

    echo ""
    echo "  Tailscale 설정 안내:"
    echo "    1. Tailscale 앱을 실행하세요"
    echo "    2. 터미널에서 'tailscale up' 실행"
    echo "    3. 화면에 나오는 URL로 로그인"
    echo -e "  ${YELLOW}!${NC} Tailscale 관리 페이지: https://login.tailscale.com/admin/machines"
}

# --------------------------------------------------
# 5. 세션 유지 도구(tmux) 설정
# --------------------------------------------------
setup_tmux() {
    echo ""
    echo -e "${BLUE}[5/9] tmux(세션 유지 도구) 설정...${NC}"

    # 기존 설정 백업
    if [ -f "$HOME/.tmux.conf" ]; then
        cp "$HOME/.tmux.conf" "$HOME/.tmux.conf.backup.$(date +%s)"
        echo -e "  ${YELLOW}!${NC} 기존 .tmux.conf 백업 완료"
    fi

    # tmux 설정 파일 생성
    cat > "$HOME/.tmux.conf" << 'TMUXEOF'
# Claude Code 서버 tmux 설정
set -g default-terminal "screen-256color"
set -g history-limit 50000
set -g mouse on
set -g set-titles on
set -g set-titles-string "#S:#W"

# 상태바
set -g status-bg colour235
set -g status-fg white
set -g status-left '[#S] '
set -g status-right '%Y-%m-%d %H:%M'

# 창과 패널 번호를 1부터 시작
set -g base-index 1
setw -g pane-base-index 1

# 창 번호 자동 재정렬
set -g renumber-windows on

# 패널 표시 시간 늘리기
set -g display-panes-time 3000
TMUXEOF

    echo -e "  ${GREEN}OK${NC} tmux 설정 완료"

    # tmux 자동 시작 (launchd) 설정
    local plist_dir="$HOME/Library/LaunchAgents"
    local plist_file="$plist_dir/com.claude.tmux-server.plist"
    mkdir -p "$plist_dir"

    cat > "$plist_file" << PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.tmux-server</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/tmux</string>
        <string>new-session</string>
        <string>-d</string>
        <string>-s</string>
        <string>claude</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
PLISTEOF

    launchctl load "$plist_file" 2>/dev/null || true
    echo -e "  ${GREEN}OK${NC} tmux 자동 시작 설정 완료"
}

# --------------------------------------------------
# 6. 방화벽 설정
# --------------------------------------------------
setup_firewall() {
    echo ""
    echo -e "${BLUE}[6/9] 방화벽 설정...${NC}"

    echo "  macOS 방화벽 활성화 중..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null || true
    echo -e "  ${GREEN}OK${NC} 방화벽 활성화 완료"
    echo -e "  ${YELLOW}!${NC} SSH 접근은 Tailscale ACL로 제어됩니다"
    echo -e "  ${YELLOW}!${NC} ACL 설정: https://login.tailscale.com/admin/acls"
}

# --------------------------------------------------
# 7. Claude Code 설정 파일 설치
# --------------------------------------------------
install_claude_config() {
    echo ""
    echo -e "${BLUE}[7/9] Claude Code 설정 파일 설치...${NC}"

    local config_dir="$HOME/claude-code-config"

    if [[ -d "$config_dir" ]]; then
        echo "  install.sh 실행 중..."
        bash "$config_dir/install.sh"
    else
        echo -e "  ${YELLOW}!${NC} 설정 저장소를 먼저 클론하세요:"
        echo "    git clone <repo-url> ~/claude-code-config"
        echo "    ~/claude-code-config/install.sh"
    fi
}

# --------------------------------------------------
# 8. 팀원 SSH 공개키 등록
# --------------------------------------------------
add_team_ssh_keys() {
    echo ""
    echo -e "${BLUE}[8/9] 팀원 SSH 키 등록...${NC}"

    echo ""
    echo "  팀원이 Windows에서 생성한 SSH 공개키를 등록합니다."
    echo "  (팀원에게 setup-windows.ps1 실행 후 공개키를 받으세요)"
    echo ""

    while true; do
        read -r -p "  팀원의 SSH 공개키를 등록할까요? (y/n): " add_key
        if [[ "$add_key" != "y" && "$add_key" != "Y" ]]; then
            break
        fi

        echo "  팀원의 SSH 공개키를 붙여넣고 Enter를 누르세요:"
        echo "  (ssh-ed25519 AAAA... 형태의 한 줄 텍스트)"
        read -r pubkey

        # 공개키 형식 검증
        if [[ -z "$pubkey" ]]; then
            echo -e "  ${RED}오류: 빈 값입니다. 다시 시도하세요.${NC}"
            continue
        fi

        if [[ ! "$pubkey" =~ ^ssh-(ed25519|rsa|ecdsa)[[:space:]] ]]; then
            echo -e "  ${RED}오류: SSH 공개키 형식이 아닙니다.${NC}"
            echo "  올바른 예: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... user@hostname"
            continue
        fi

        # 중복 확인
        if grep -qF "$pubkey" "$HOME/.ssh/authorized_keys" 2>/dev/null; then
            echo -e "  ${YELLOW}!${NC} 이미 등록된 키입니다. 건너뜁니다."
            continue
        fi

        # authorized_keys에 추가
        echo "$pubkey" >> "$HOME/.ssh/authorized_keys"
        echo -e "  ${GREEN}OK${NC} 키가 등록되었습니다."
        echo ""
    done

    # 등록된 키 수 표시
    local key_count
    key_count=$(wc -l < "$HOME/.ssh/authorized_keys" | tr -d ' ')
    echo -e "  현재 등록된 SSH 키: ${GREEN}${key_count}개${NC}"
}

# --------------------------------------------------
# 9. SSH 비밀번호 인증 비활성화 (마지막 단계, 안전 확인 후)
# --------------------------------------------------
harden_ssh() {
    echo ""
    echo -e "${BLUE}[9/9] SSH 보안 강화 (비밀번호 인증 차단)...${NC}"

    # 등록된 키 확인
    local key_count
    key_count=$(wc -l < "$HOME/.ssh/authorized_keys" | tr -d ' ')

    if [[ "$key_count" -eq 0 ]]; then
        echo -e "  ${RED}경고: 등록된 SSH 키가 없습니다!${NC}"
        echo -e "  ${RED}비밀번호 인증을 차단하면 원격 접속이 불가능해집니다.${NC}"
        echo -e "  ${YELLOW}먼저 팀원의 SSH 키를 등록한 후 다시 이 스크립트를 실행하세요.${NC}"
        echo -e "  ${YELLOW}비밀번호 인증은 유지됩니다.${NC}"
        return 0
    fi

    echo ""
    echo "  현재 등록된 SSH 키: ${key_count}개"
    echo ""
    echo -e "  ${YELLOW}주의: 비밀번호로 접속이 불가능해집니다.${NC}"
    echo "  SSH 키 접속이 정상 작동하는지 먼저 테스트하세요."
    echo ""
    echo "  테스트 방법 (다른 터미널에서):"
    echo "    ssh $(whoami)@localhost"
    echo "    또는 팀원 PC에서: ssh $(whoami)@$(hostname).tailscale.com"
    echo ""

    if ! confirm_step "  비밀번호로 접속이 불가능해집니다. SSH 키 접속을 테스트했나요?"; then
        echo -e "  ${YELLOW}비밀번호 인증을 유지합니다.${NC}"
        echo "  나중에 준비되면 이 스크립트를 다시 실행하세요."
        return 0
    fi

    # SSH 하드닝 설정 적용
    local custom_config="/etc/ssh/sshd_config.d/claude-hardening.conf"
    sudo mkdir -p /etc/ssh/sshd_config.d

    sudo tee "$custom_config" > /dev/null << 'SSHEOF'
# Claude Code 서버 SSH 보안 설정
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitRootLogin no
MaxAuthTries 3
ClientAliveInterval 120
ClientAliveCountMax 3
SSHEOF

    echo -e "  ${GREEN}OK${NC} SSH 보안 강화 완료 (비밀번호 인증 차단됨)"
    echo -e "  ${YELLOW}!${NC} 문제 발생 시 물리적으로 Mac에 접근하여 아래 파일을 삭제하세요:"
    echo "    sudo rm $custom_config"
}

# --------------------------------------------------
# Main
# --------------------------------------------------
main() {
    if [[ "$(uname)" != "Darwin" ]]; then
        echo -e "${RED}이 스크립트는 macOS 전용입니다.${NC}"
        exit 1
    fi

    setup_system        # 1. 시스템 설정 (절전, 호스트명)
    setup_ssh           # 2. SSH 활성화 (비밀번호 인증 유지)
    install_tools       # 3. 개발 도구 설치
    install_tailscale   # 4. Tailscale VPN
    setup_tmux          # 5. tmux 설정
    setup_firewall      # 6. 방화벽
    install_claude_config # 7. Claude Code 설정
    add_team_ssh_keys   # 8. 팀원 SSH 키 등록
    harden_ssh          # 9. 비밀번호 인증 차단 (마지막!)

    echo ""
    echo -e "${GREEN}Mac 서버 설정이 완료되었습니다!${NC}"
    echo ""
    echo "설정 후 확인사항:"
    echo "  [ ] 'tailscale up' 실행하여 VPN 연결"
    echo "  [ ] 팀원이 SSH 접속 가능한지 확인"
    echo "  [ ] tmux 세션 확인: tmux attach -t claude"
    echo "  [ ] Claude Code 시작: claude"
    echo "  [ ] Time Machine 백업 설정"
    echo ""
    echo "팀원 접속 명령어:"
    echo "  ssh $(whoami)@$(hostname).tailscale.com"
    echo ""
}

main "$@"
