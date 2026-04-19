#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

# Defaults
UPGRADE_MODE=0
DRY_RUN=0

# Usage banner
print_usage_and_exit() {
    cat << USAGE
Usage: install.sh [OPTIONS]

Options:
  --upgrade     Upgrade existing installation to v3.0 (preserves symlinks,
                refreshes targets, prints breaking-change guidance).
  --dry-run     Show what would change without modifying files.
  -h, --help    Show this help message.

Examples:
  ./install.sh                 # Fresh install
  ./install.sh --upgrade       # Upgrade v2.x -> v3.0 in place
  ./install.sh --dry-run       # Preview changes
  ./install.sh --upgrade --dry-run

v3.0 Breaking Changes (see docs/MIGRATION.md):
  - MCP servers: 6 -> 3 (playwright, context7, jina-reader)
  - Hooks: 5 events -> 21 (opt-in via hooks/examples/)
  - Subagent frontmatter: v2 optional fields
  - Skills/Commands: hybrid policy (docs/SKILLS-VS-COMMANDS.md)
USAGE
    exit 0
}

# Parse arguments
while [ $# -gt 0 ]; do
    case "${1:-}" in
        --upgrade)
            UPGRADE_MODE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            print_usage_and_exit
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Run './install.sh --help' for usage." >&2
            exit 1
            ;;
    esac
done

# Detect platform
detect_platform() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        PLATFORM="macos"
        ARCH="$(uname -m)"
    elif grep -qEi "(Microsoft|WSL)" /proc/version 2>/dev/null || [ -f /proc/sys/fs/binfmt_misc/WSLInterop ]; then
        PLATFORM="wsl"
        ARCH="$(uname -m)"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        PLATFORM="linux"
        ARCH="$(uname -m)"
    else
        PLATFORM="unknown"
        ARCH="$(uname -m)"
    fi
}

detect_platform

cat << 'BANNER'

   ╔═╗┬  ┌─┐┬ ┬┌┬┐┌─┐  ╔═╗┌─┐┬─┐┌─┐┌─┐
   ║  │  ├─┤│ │ ││├┤   ╠╣ │ │├┬┘│ ┬├┤
   ╚═╝┴─┘┴ ┴└─┘─┴┘└─┘  ╚  └─┘┴└─└─┘└─┘

   Production-grade Claude Code Framework
   github.com/sangrokjung/claude-forge

BANNER
echo "Platform: $PLATFORM ($ARCH)"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Upgrade banner (printed when --upgrade is set)
print_upgrade_banner() {
    echo "=========================================="
    echo "  claude-forge v3.0 Upgrade"
    echo "=========================================="
    echo ""
    echo "  Breaking changes since v2.1:"
    echo "  - MCP: 6 servers -> 3 (playwright, context7, jina-reader)"
    echo "    - Removed: memory, exa, github, fetch"
    echo "    - Recipes: docs/MCP-MIGRATION.md"
    echo "  - Hooks: 5 events -> 21 (opt-in via hooks/examples/)"
    echo "  - Subagent frontmatter: v2 optional fields"
    echo "  - Skills/Commands: hybrid policy (docs/SKILLS-VS-COMMANDS.md)"
    echo ""
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "  ${YELLOW}[DRY-RUN] No files will be modified.${NC}"
        echo ""
    fi
}

# v3.0 skills/commands 호환 링크 (v2.1에서 commands로 제공되던 항목 일부가
# v3.0에서 skills로 이동한 경우에 대한 하위 호환)
create_v3_compat_links() {
    local target_base="$CLAUDE_DIR"
    local created=0

    # v2.1 경로 -> v3.0 경로 매핑
    # v2.1의 commands/ 디렉토리형 skill(8개)이 v3.0에서 skills/로 이전됨.
    # 기존 참조를 깨지 않도록 심볼릭 링크로 호환성 유지 (2027-04-01까지).
    local mappings=(
        "commands/debugging-strategies:skills/debugging-strategies"
        "commands/dependency-upgrade:skills/dependency-upgrade"
        "commands/evaluating-code-models:skills/evaluating-code-models"
        "commands/evaluating-llms-harness:skills/evaluating-llms-harness"
        "commands/extract-errors:skills/extract-errors"
        "commands/security-compliance:skills/security-compliance"
        "commands/stride-analysis-patterns:skills/stride-analysis-patterns"
        "commands/summarize:skills/summarize"
    )

    for mapping in "${mappings[@]}"; do
        local old_path="${mapping%%:*}"
        local new_path="${mapping##*:}"
        local new_target="$REPO_DIR/$new_path"
        local old_link="$target_base/$old_path"

        if [ -e "$new_target" ] && [ ! -e "$old_link" ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "  [DRY-RUN] would create compat link: $old_path -> $new_path"
            else
                mkdir -p "$(dirname "$old_link")"
                ln -sf "$new_target" "$old_link" 2>/dev/null && \
                    echo -e "  ${GREEN}✓${NC} compat link: $old_path -> $new_path" && \
                    created=$((created + 1)) || true
            fi
        fi
    done

    if [ "$created" -eq 0 ] && [ "$DRY_RUN" -ne 1 ]; then
        echo "  (no compat links needed)"
    fi
}

# Upgrade-mode summary
print_upgrade_summary() {
    echo ""
    echo "=========================================="
    echo "  Upgrade Summary"
    echo "=========================================="
    echo "  Version       : v3.0.0"
    echo "  Mode          : $([ "$DRY_RUN" -eq 1 ] && echo 'dry-run' || echo 'applied')"
    echo "  Repo          : $REPO_DIR"
    echo "  Target        : $CLAUDE_DIR"
    echo ""
    echo "  Expected counts:"
    echo "    - 11 agents, 24 skills (16 native + 8 moved from commands), 33 commands, 9+ rules, 15 hooks + 9 opt-in examples"
    echo ""
    echo "  Next steps:"
    echo "    1. Review docs/MIGRATION.md for detailed changes"
    echo "    2. Opt-in new hooks from hooks/examples/ as needed"
    echo "    3. Run 'claude mcp list' to verify 3 MCP servers"
    echo ""
}

# 1. Check dependencies
check_deps() {
    echo "Checking dependencies..."
    local missing=()

    command -v node >/dev/null || missing+=("node")
    command -v jq >/dev/null || missing+=("jq")
    command -v git >/dev/null || missing+=("git")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}Missing dependencies: ${missing[*]}${NC}"
        echo ""
        case "$PLATFORM" in
            macos)
                echo "Install with: brew install ${missing[*]}"
                ;;
            wsl|linux)
                echo "Install with: sudo apt install ${missing[*]}"
                echo "  or: curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -"
                ;;
            *)
                echo "Install with your package manager"
                ;;
        esac
        echo ""
        echo -e "${YELLOW}Need help? github.com/sangrokjung/claude-forge/issues${NC}"
        exit 1
    fi

    echo -e "${GREEN}All dependencies satisfied${NC}"
}

# 2. Initialize git submodules (cc-chips)
init_submodules() {
    echo ""
    echo "Initializing git submodules..."

    cd "$REPO_DIR"
    git submodule update --init --recursive 2>/dev/null && \
        echo -e "${GREEN}Submodules initialized (cc-chips)${NC}" || \
        echo -e "${YELLOW}Submodule init skipped (may already be initialized)${NC}"
}

# 3. Backup existing config
backup() {
    if [ -d "$CLAUDE_DIR" ]; then
        local backup_dir="$CLAUDE_DIR.backup.$(date +%Y%m%d_%H%M%S)"
        echo ""
        echo -e "${YELLOW}Existing ~/.claude found${NC}"

        # Upgrade mode: skip wholesale move, just refresh symlinks in place
        if [ "$UPGRADE_MODE" -eq 1 ]; then
            echo "  Upgrade mode: preserving $CLAUDE_DIR (symlinks will be refreshed)."
            return 0
        fi

        read -p "Backup to $backup_dir? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "  [DRY-RUN] would mv $CLAUDE_DIR -> $backup_dir"
            else
                mv "$CLAUDE_DIR" "$backup_dir"
                echo -e "${GREEN}Backed up to $backup_dir${NC}"
            fi
        else
            echo "Skipping backup. Existing files may be overwritten."
        fi
    fi
}

# 4. Create symlinks (or copies on WSL cross-filesystem)
link_files() {
    echo ""

    # WSL: if repo is on Windows filesystem (/mnt/c/...), use copies instead of symlinks
    local use_copy=false
    if [[ "$PLATFORM" == "wsl" ]] && [[ "$REPO_DIR" == /mnt/* ]]; then
        echo -e "${YELLOW}WSL detected with Windows filesystem path. Using copies instead of symlinks.${NC}"
        echo "  Tip: Clone repo to ~/claude-forge for symlink support."
        use_copy=true
    fi

    if [ "$use_copy" = true ]; then
        echo "Copying configuration files..."
    else
        echo "Creating symlinks..."
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo "  [DRY-RUN] would mkdir -p $CLAUDE_DIR"
    else
        mkdir -p "$CLAUDE_DIR"
    fi

    # Directories
    for dir in agents rules commands scripts skills hooks cc-chips cc-chips-custom; do
        if [ -d "$REPO_DIR/$dir" ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "  [DRY-RUN] would refresh $dir/"
                continue
            fi
            rm -rf "$CLAUDE_DIR/$dir" 2>/dev/null || true
            if [ "$use_copy" = true ]; then
                cp -r "$REPO_DIR/$dir" "$CLAUDE_DIR/$dir"
                echo "  Copied: $dir/"
            else
                ln -sf "$REPO_DIR/$dir" "$CLAUDE_DIR/$dir"
                echo "  Linked: $dir/"
            fi
        fi
    done

    # Files
    for file in settings.json; do
        if [ -f "$REPO_DIR/$file" ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                echo "  [DRY-RUN] would refresh $file"
                continue
            fi
            rm -f "$CLAUDE_DIR/$file" 2>/dev/null || true
            if [ "$use_copy" = true ]; then
                cp "$REPO_DIR/$file" "$CLAUDE_DIR/$file"
                echo "  Copied: $file"
            else
                ln -sf "$REPO_DIR/$file" "$CLAUDE_DIR/$file"
                echo "  Linked: $file"
            fi
        fi
    done
}

# 4b. Validate mcp-servers.json for v3.0 (3 core entries)
validate_mcp_v3() {
    local mcp_json="$REPO_DIR/mcp-servers.json"
    if [ ! -f "$mcp_json" ] || ! command -v jq >/dev/null; then
        return 0
    fi

    echo ""
    echo "Validating mcp-servers.json (v3.0 minimal profile)..."

    # v3.0 schema uses `.servers.<name>`; legacy v2.x used `.install_commands.<name>`
    local expected=("playwright" "context7" "jina-reader")
    local missing=()
    for s in "${expected[@]}"; do
        local present=0
        if jq -e --arg s "$s" '.servers[$s] // empty' "$mcp_json" >/dev/null 2>&1; then
            present=1
        elif jq -e --arg s "$s" '.install_commands[$s] // empty' "$mcp_json" >/dev/null 2>&1; then
            present=1
        fi
        [ "$present" -eq 0 ] && missing+=("$s")
    done

    local server_count
    server_count=$(jq -r '.servers | length // 0' "$mcp_json" 2>/dev/null || echo 0)

    if [ ${#missing[@]} -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} v3.0 core MCP entries present (3/3, total=$server_count)"
    else
        echo -e "  ${YELLOW}!${NC} Missing v3.0 MCP entries: ${missing[*]}"
        echo "    See docs/MCP-MIGRATION.md for remediation."
    fi
}

# 5. Apply CC CHIPS custom overlay
apply_cc_chips_custom() {
    local custom_dir="$REPO_DIR/cc-chips-custom"
    if [ -d "$custom_dir" ]; then
        echo ""
        echo "Applying CC CHIPS custom overlay..."

        if [ "$DRY_RUN" -eq 1 ]; then
            echo "  [DRY-RUN] would overlay engine.sh + themes/*.sh"
            return 0
        fi

        local target="$CLAUDE_DIR/cc-chips"

        if [ -f "$custom_dir/engine.sh" ] && [ -d "$target" ]; then
            cp "$custom_dir/engine.sh" "$target/engine.sh"
            chmod +x "$target/engine.sh"
            echo -e "  ${GREEN}✓${NC} engine.sh (model detection + session ID + cache stats)"
        fi

        if [ -d "$custom_dir/themes" ] && [ -d "$target/themes" ]; then
            cp "$custom_dir/themes/"*.sh "$target/themes/" 2>/dev/null
            echo -e "  ${GREEN}✓${NC} themes/ (stats chip colors)"
        fi

        echo -e "${GREEN}CC CHIPS custom overlay applied!${NC}"
    fi
}

# 6. Install MCP servers
install_mcp_servers() {
    echo ""
    echo "Installing MCP servers..."

    # Check if claude CLI is available
    if ! command -v claude >/dev/null; then
        echo -e "${YELLOW}Claude CLI not found. Skipping MCP server installation.${NC}"
        echo "Install Claude CLI first, then re-run this script."
        return 0
    fi

    read -p "Install recommended MCP servers? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping MCP server installation."
        return 0
    fi

    # Read install commands from mcp-servers.json if available
    local mcp_json="$REPO_DIR/mcp-servers.json"
    if [ -f "$mcp_json" ] && command -v jq >/dev/null; then
        echo "  Installing from mcp-servers.json..."

        # Core servers (no API key required)
        local core_servers=("context7" "sequential-thinking" "memory" "youtube-transcript" "remotion" "playwright" "desktop-commander")
        for server in "${core_servers[@]}"; do
            local cmd
            cmd=$(jq -r ".install_commands.\"$server\" // empty" "$mcp_json")
            if [ -n "$cmd" ]; then
                echo "  Installing $server..."
                eval "$cmd" 2>/dev/null && \
                    echo -e "  ${GREEN}✓${NC} $server" || \
                    echo -e "  ${YELLOW}!${NC} $server (already installed or failed)"
            fi
        done

        # Optional servers
        echo ""
        echo -e "${YELLOW}Optional servers (may require authentication):${NC}"

        local optional_servers=("exa" "gmail" "google-calendar" "n8n-mcp" "hyperbrowser" "stitch" "sentry" "supabase" "github")
        for server in "${optional_servers[@]}"; do
            local cmd
            cmd=$(jq -r ".install_commands.\"$server\" // empty" "$mcp_json")
            if [ -n "$cmd" ]; then
                read -p "  Install $server? (y/n) " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    eval "$cmd" 2>/dev/null && \
                        echo -e "  ${GREEN}✓${NC} $server" || \
                        echo -e "  ${YELLOW}!${NC} $server (already installed or failed)"
                fi
            fi
        done

        # Korean public data servers
        echo ""
        read -p "  Install Korean public data servers (NTS, NPS, PPS, FSC, MSDS)? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for server in "data-go-nts" "data-go-nps" "data-go-pps" "data-go-fsc" "data-go-msds"; do
                local cmd
                cmd=$(jq -r ".install_commands.\"$server\" // empty" "$mcp_json")
                if [ -n "$cmd" ]; then
                    eval "$cmd" 2>/dev/null && \
                        echo -e "  ${GREEN}✓${NC} $server" || \
                        echo -e "  ${YELLOW}!${NC} $server (already installed or failed)"
                fi
            done
        fi

        # Financial data servers
        echo ""
        read -p "  Install financial data servers (CoinGecko, Alpha Vantage, FRED, Korea Stock)? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for server in "coingecko" "alpha-vantage" "fred" "korea-stock"; do
                local cmd
                cmd=$(jq -r ".install_commands.\"$server\" // empty" "$mcp_json")
                if [ -n "$cmd" ]; then
                    eval "$cmd" 2>/dev/null && \
                        echo -e "  ${GREEN}✓${NC} $server" || \
                        echo -e "  ${YELLOW}!${NC} $server (already installed or failed)"
                fi
            done
        fi
    else
        # Fallback: minimal install without mcp-servers.json
        echo "  Installing core MCP servers..."

        claude mcp add context7 -- npx -y @upstash/context7-mcp 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} context7" || echo -e "  ${YELLOW}!${NC} context7"

        claude mcp add playwright -- npx @playwright/mcp@latest 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} playwright" || echo -e "  ${YELLOW}!${NC} playwright"

        claude mcp add memory -- npx -y @modelcontextprotocol/server-memory 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} memory" || echo -e "  ${YELLOW}!${NC} memory"

        claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking 2>/dev/null && \
            echo -e "  ${GREEN}✓${NC} sequential-thinking" || echo -e "  ${YELLOW}!${NC} sequential-thinking"
    fi

    echo ""
    echo -e "${GREEN}MCP server installation complete!${NC}"
    echo "Run 'claude mcp list' to verify installed servers."
}

# 7. Install external skills (npx skills)
install_external_skills() {
    echo ""
    echo "Installing external skills..."

    if ! command -v npx >/dev/null; then
        echo -e "${YELLOW}npx not found. Skipping external skills installation.${NC}"
        return 0
    fi

    read -p "Install external skills (Superpowers, Humanizer, UI/UX Pro Max, Find Skills)? (y/n) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping external skills installation."
        return 0
    fi

    echo "  Installing Superpowers (14 skills)..."
    npx -y skills add obra/superpowers -y -g 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} superpowers" || echo -e "  ${YELLOW}!${NC} superpowers (failed)"

    echo "  Installing Humanizer..."
    npx -y skills add blader/humanizer -y -g 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} humanizer" || echo -e "  ${YELLOW}!${NC} humanizer (failed)"

    echo "  Installing UI/UX Pro Max..."
    npx -y skills add nextlevelbuilder/ui-ux-pro-max-skill -y -g 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} ui-ux-pro-max" || echo -e "  ${YELLOW}!${NC} ui-ux-pro-max (failed)"

    echo "  Installing Find Skills..."
    npx -y skills add vercel-labs/skills -y -g 2>/dev/null && \
        echo -e "  ${GREEN}✓${NC} find-skills" || echo -e "  ${YELLOW}!${NC} find-skills (failed)"

    echo ""
    echo -e "${GREEN}External skills installation complete!${NC}"
}

# 8. Setup shell aliases
setup_shell_aliases() {
    echo ""
    echo "Setting up shell aliases..."

    local shell_rc=""
    if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        shell_rc="$HOME/.bashrc"
    fi

    if [ -z "$shell_rc" ]; then
        echo -e "${YELLOW}No .zshrc or .bashrc found. Skipping aliases.${NC}"
        return 0
    fi

    local marker="# Claude Code aliases"
    if grep -q "$marker" "$shell_rc" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Aliases already configured in $(basename "$shell_rc")"
        return 0
    fi

    cat >> "$shell_rc" << 'ALIASES'

# Claude Code aliases
alias cc='claude'
alias ccr='claude --resume'
ALIASES

    echo -e "  ${GREEN}✓${NC} Added aliases to $(basename "$shell_rc")"
    echo "    cc  → claude"
    echo "    ccr → claude --resume"
}

# 9. Verify installation
verify() {
    echo ""
    echo "Verifying installation..."

    local errors=0

    for item in agents rules commands scripts skills cc-chips cc-chips-custom hooks settings.json; do
        if [ -L "$CLAUDE_DIR/$item" ] && [ ! -e "$CLAUDE_DIR/$item" ]; then
            echo -e "  ${RED}✗${NC} $item (broken symlink)"
            errors=$((errors + 1))
        elif [ -L "$CLAUDE_DIR/$item" ] || [ -e "$CLAUDE_DIR/$item" ]; then
            echo -e "  ${GREEN}✓${NC} $item"
        else
            echo -e "  ${RED}✗${NC} $item (not found)"
            errors=$((errors + 1))
        fi
    done

    return $errors
}

# 10. Write forge metadata
write_meta() {
    echo ""
    echo "Writing forge metadata..."

    # install_mode 판단: agents가 symlink이면 symlink, 아니면 copy
    local install_mode="symlink"
    if [ ! -L "$CLAUDE_DIR/agents" ] && [ -d "$CLAUDE_DIR/agents" ]; then
        install_mode="copy"
    fi

    # plugin.json에서 버전 읽기
    local version="1.0.0"
    if [ -f "$REPO_DIR/.claude-plugin/plugin.json" ] && command -v jq >/dev/null; then
        version=$(jq -r '.version // "1.0.0"' "$REPO_DIR/.claude-plugin/plugin.json")
    fi

    # git 정보
    local git_commit=""
    local remote_url=""
    if command -v git >/dev/null && [ -d "$REPO_DIR/.git" ]; then
        git_commit=$(cd "$REPO_DIR" && git rev-parse --short HEAD 2>/dev/null || echo "")
        remote_url=$(cd "$REPO_DIR" && git remote get-url origin 2>/dev/null || echo "")
    fi

    local now
    now=$(date +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S")

    # 기존 메타파일이 있으면 installed_at 보존
    local installed_at="$now"
    if [ -f "$CLAUDE_DIR/.forge-meta.json" ] && command -v jq >/dev/null; then
        local prev_installed
        prev_installed=$(jq -r '.installed_at // ""' "$CLAUDE_DIR/.forge-meta.json")
        if [ -n "$prev_installed" ] && [ "$prev_installed" != "null" ]; then
            installed_at="$prev_installed"
        fi
    fi

    # jq로 안전하게 JSON 생성 (경로 인젝션 방지)
    jq -n \
      --arg repo_path "$REPO_DIR" \
      --arg install_mode "$install_mode" \
      --arg installed_at "$installed_at" \
      --arg updated_at "$now" \
      --arg version "$version" \
      --arg git_commit "$git_commit" \
      --arg remote_url "$remote_url" \
      --arg platform "$PLATFORM" \
      '{
        repo_path: $repo_path,
        install_mode: $install_mode,
        installed_at: $installed_at,
        updated_at: $updated_at,
        version: $version,
        git_commit: $git_commit,
        remote_url: $remote_url,
        platform: $platform
      }' > "$CLAUDE_DIR/.forge-meta.json"

    chmod 600 "$CLAUDE_DIR/.forge-meta.json"
    echo -e "  ${GREEN}✓${NC} .forge-meta.json"
}

# 11. Install work tracker (Supabase sync)
install_work_tracker() {
    local wt_script="$REPO_DIR/setup/work-tracker-install.sh"
    if [ -f "$wt_script" ]; then
        echo ""
        read -p "Install Work Tracker (Claude Code usage tracking → Supabase)? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            REPO_DIR="$REPO_DIR" bash "$wt_script"
        else
            echo "Skipping Work Tracker installation."
        fi
    fi
}

# Main
main() {
    if [ "$UPGRADE_MODE" -eq 1 ]; then
        print_upgrade_banner
    fi

    check_deps
    init_submodules
    backup
    link_files
    apply_cc_chips_custom
    validate_mcp_v3

    # v3.0 compat symlinks (upgrade mode only)
    if [ "$UPGRADE_MODE" -eq 1 ]; then
        echo ""
        echo "Creating v3.0 compat links..."
        create_v3_compat_links
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        echo ""
        echo -e "${YELLOW}[DRY-RUN] Skipping verify/metadata/MCP/skills/tracker steps.${NC}"
        if [ "$UPGRADE_MODE" -eq 1 ]; then
            print_upgrade_summary
        fi
        return 0
    fi

    if verify; then
        echo ""
        echo -e "${GREEN}Symlinks created successfully!${NC}"

        # Write forge metadata
        write_meta

        # Setup shell aliases
        setup_shell_aliases

        # Install MCP servers
        install_mcp_servers

        # Install external skills
        install_external_skills

        # Install work tracker
        install_work_tracker

        if [ "$UPGRADE_MODE" -eq 1 ]; then
            print_upgrade_summary
        fi

        echo ""
        cat << COMPLETE

  ${GREEN}╔══════════════════════════════════════════════════════╗
  ║           Claude Forge 설치 완료!                    ║
  ╠══════════════════════════════════════════════════════╣
  ║  11 agents · 36+ commands · 6-layer security        ║
  ╚══════════════════════════════════════════════════════╝${NC}

  처음이신가요? 이것만 하세요:
    1. 새 터미널을 열고 'claude' 실행
    2. ${GREEN}/guide${NC} 입력 — 3분 인터랙티브 가이드

  자주 쓰는 TOP 5:
    /plan           AI가 구현 계획을 세워줍니다
    /tdd            테스트 먼저 만들고 코드 작성
    /code-review    코드 보안+품질 검사
    /handoff-verify 빌드/테스트/린트 자동 검증
    /auto           계획부터 PR까지 원버튼 자동

  ${YELLOW}★ Star: github.com/sangrokjung/claude-forge${NC}
  ${YELLOW}? Issues: github.com/sangrokjung/claude-forge/issues${NC}

COMPLETE
    else
        echo ""
        echo -e "${RED}Installation completed with errors${NC}"
        exit 1
    fi
}

main "$@"
