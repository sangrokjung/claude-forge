#!/bin/bash
set -e

#
# GitHub Actions Self-Hosted Runner Setup for iMac Pro
# Configures the existing iMac Pro as a CI/CD runner
#
# Usage: ./setup-cicd-runner.sh --repo OWNER/REPO --token RUNNER_TOKEN
#

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO=""
TOKEN=""
RUNNER_DIR="$HOME/actions-runner"
LABELS="self-hosted,macOS,Intel,iMac-Pro"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --repo) REPO="$2"; shift ;;
        --token) TOKEN="$2"; shift ;;
        --labels) LABELS="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

echo -e "${BLUE}GitHub Actions Runner Setup (iMac Pro)${NC}"
echo "======================================="
echo ""

# --------------------------------------------------
# 1. Validate inputs
# --------------------------------------------------
validate() {
    echo -e "${BLUE}[1/5] Validating inputs...${NC}"

    if [[ -z "$REPO" ]]; then
        echo -e "${RED}Error: --repo is required (e.g., owner/repo)${NC}"
        echo "Usage: ./setup-cicd-runner.sh --repo OWNER/REPO --token RUNNER_TOKEN"
        echo ""
        echo "Get a runner token from:"
        echo "  https://github.com/OWNER/REPO/settings/actions/runners/new"
        exit 1
    fi

    if [[ -z "$TOKEN" ]]; then
        echo "Get a runner token from: https://github.com/$REPO/settings/actions/runners/new"
        read -sp "  Enter runner token: " TOKEN
        echo ""
        if [[ -z "$TOKEN" ]]; then
            echo -e "${RED}Error: Token is required${NC}"
            exit 1
        fi
    fi

    echo -e "  ${GREEN}✓${NC} Repo: $REPO"
    echo -e "  ${GREEN}✓${NC} Labels: $LABELS"
}

# --------------------------------------------------
# 2. Install Docker
# --------------------------------------------------
install_docker() {
    echo ""
    echo -e "${BLUE}[2/5] Setting up Docker...${NC}"

    if command -v docker >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Docker already installed"
        docker --version | sed 's/^/  /'
    else
        echo "  Installing Docker Desktop..."
        brew install --cask docker 2>/dev/null || \
            echo -e "  ${YELLOW}!${NC} Install Docker Desktop from https://www.docker.com/products/docker-desktop/"
    fi
}

# --------------------------------------------------
# 3. Download and configure runner
# --------------------------------------------------
setup_runner() {
    echo ""
    echo -e "${BLUE}[3/5] Setting up GitHub Actions runner...${NC}"

    if [[ -d "$RUNNER_DIR" ]]; then
        echo -e "  ${YELLOW}!${NC} Runner directory exists at $RUNNER_DIR"
        read -p "  Remove and reinstall? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cd "$RUNNER_DIR"
            ./svc.sh uninstall 2>/dev/null || true
            cd "$HOME"
            rm -rf "$RUNNER_DIR"
        else
            echo "  Skipping runner installation."
            return 0
        fi
    fi

    mkdir -p "$RUNNER_DIR"
    cd "$RUNNER_DIR"

    echo "  Downloading latest runner..."
    local runner_version
    runner_version=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | jq -r '.tag_name' | sed 's/^v//')

    if [[ ! "$runner_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo -e "${RED}Failed to fetch runner version. Check network and GitHub API limits.${NC}"
        exit 1
    fi

    local arch="x64"
    if [[ "$(uname -m)" == "arm64" ]]; then
        arch="arm64"
    fi

    curl -o actions-runner.tar.gz -L \
        "https://github.com/actions/runner/releases/download/v${runner_version}/actions-runner-osx-${arch}-${runner_version}.tar.gz"
    tar xzf actions-runner.tar.gz
    rm actions-runner.tar.gz

    echo -e "  ${GREEN}✓${NC} Runner v${runner_version} downloaded"

    echo "  Configuring runner..."
    ./config.sh \
        --url "https://github.com/$REPO" \
        --token "$TOKEN" \
        --labels "$LABELS" \
        --name "imac-pro-runner" \
        --work "_work" \
        --replace

    echo -e "  ${GREEN}✓${NC} Runner configured"
}

# --------------------------------------------------
# 4. Install as launchd service
# --------------------------------------------------
install_service() {
    echo ""
    echo -e "${BLUE}[4/5] Installing as system service...${NC}"

    cd "$RUNNER_DIR"

    ./svc.sh install
    ./svc.sh start

    echo -e "  ${GREEN}✓${NC} Runner service installed and started"
    echo ""
    echo "  Service management:"
    echo "    $RUNNER_DIR/svc.sh status"
    echo "    $RUNNER_DIR/svc.sh stop"
    echo "    $RUNNER_DIR/svc.sh start"
}

# --------------------------------------------------
# 5. Verify
# --------------------------------------------------
verify_runner() {
    echo ""
    echo -e "${BLUE}[5/5] Verifying runner...${NC}"

    cd "$RUNNER_DIR"
    ./svc.sh status

    echo ""
    echo -e "${GREEN}Runner setup complete!${NC}"
    echo ""
    echo "Verify at: https://github.com/$REPO/settings/actions/runners"
    echo ""
    echo "Usage in workflow:"
    echo "  jobs:"
    echo "    build:"
    echo "      runs-on: [self-hosted, macOS, Intel, iMac-Pro]"
    echo ""
    echo "System info:"
    echo "  CPU: $(sysctl -n machdep.cpu.brand_string)"
    echo "  RAM: $(( $(sysctl -n hw.memsize) / 1073741824 ))GB"
    echo "  Disk: $(df -h / | awk 'NR==2{print $4}') available"
}

# --------------------------------------------------
# Main
# --------------------------------------------------
main() {
    validate
    install_docker
    setup_runner
    install_service
    verify_runner
}

main "$@"
