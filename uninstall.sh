#!/bin/bash
# uninstall.sh — Claude Forge 안전 제거
#
# 동작:
#   1. ~/.claude 안의 forge가 만든 항목만 정리 (symlink 또는 forge 소유 디렉토리)
#   2. .forge-meta.json, .forge-update-last-check 정리
#   3. 셸 alias(cc, ccr) 제거 (rc 파일 백업 후)
#   4. 사용자 데이터(history.jsonl, file-history/, projects/, backups/, cache/, ide/, debug/, metrics/, homunculus/) 절대 건드리지 않음
#
# 옵션:
#   --restore-backup   가장 최신 ~/.claude.backup.* 가 있으면 복원 시도
#   --keep-aliases     셸 alias 제거하지 않음
#   --dry-run          실제 변경 없이 어떤 동작이 일어날지만 출력
#   -y, --yes          모든 확인 프롬프트를 자동 승인

set -e

CLAUDE_DIR="$HOME/.claude"
DRY_RUN=false
RESTORE=false
KEEP_ALIASES=false
ASSUME_YES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true ;;
        --restore-backup) RESTORE=true ;;
        --keep-aliases) KEEP_ALIASES=true ;;
        -y|--yes) ASSUME_YES=true ;;
        -h|--help)
            sed -n '2,20p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
    shift
done

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
DIM='\033[2m'
NC='\033[0m'

run() {
    if $DRY_RUN; then
        echo -e "  ${DIM}[dry-run]${NC} $*"
    else
        eval "$@"
    fi
}

confirm() {
    local prompt="$1"
    if $ASSUME_YES; then
        return 0
    fi
    read -p "$prompt (y/n) " -n 1 -r
    echo ""
    [[ $REPLY =~ ^[Yy]$ ]]
}

# 0. Check ~/.claude exists
if [ ! -d "$CLAUDE_DIR" ]; then
    echo -e "${YELLOW}~/.claude not found. Nothing to uninstall.${NC}"
    exit 0
fi

cat << 'BANNER'

   ╔═╗┬  ┌─┐┬ ┬┌┬┐┌─┐  ╔═╗┌─┐┬─┐┌─┐┌─┐
   ║  │  ├─┤│ │ ││├┤   ╠╣ │ │├┬┘│ ┬├┤
   ╚═╝┴─┘┴ ┴└─┘─┴┘└─┘  ╚  └─┘┴└─└─┘└─┘   uninstall

BANNER

if $DRY_RUN; then
    echo -e "${YELLOW}DRY RUN — no files will be modified${NC}"
    echo ""
fi

# 1. Read meta to identify the install
META="$CLAUDE_DIR/.forge-meta.json"
REPO_PATH=""
if [ -f "$META" ] && command -v jq >/dev/null; then
    REPO_PATH=$(jq -r '.repo_path // ""' "$META" 2>/dev/null)
    INSTALL_MODE=$(jq -r '.install_mode // ""' "$META" 2>/dev/null)
    VERSION=$(jq -r '.version // ""' "$META" 2>/dev/null)
    echo "Found install:"
    echo "  repo:    ${REPO_PATH:-<unknown>}"
    echo "  mode:    ${INSTALL_MODE:-<unknown>}"
    echo "  version: ${VERSION:-<unknown>}"
    echo ""
fi

if ! confirm "Proceed with uninstall?"; then
    echo "Aborted."
    exit 0
fi

# 2. Items forge installs
FORGE_ITEMS=(agents rules commands scripts skills hooks cc-chips cc-chips-custom settings.json)

echo ""
echo "Removing forge-managed items from ~/.claude ..."
for item in "${FORGE_ITEMS[@]}"; do
    target="$CLAUDE_DIR/$item"
    if [ -L "$target" ]; then
        # Symlink — verify it points into REPO_PATH if known, then remove
        link_target=$(readlink "$target" 2>/dev/null || true)
        if [ -n "$REPO_PATH" ] && [[ "$link_target" != "$REPO_PATH"* ]]; then
            echo -e "  ${YELLOW}skip${NC} $item (symlink points outside repo: $link_target)"
            continue
        fi
        run "rm -f \"$target\""
        echo -e "  ${GREEN}✓${NC} unlinked $item"
    elif [ -e "$target" ]; then
        # Copy mode — remove only if metadata says install_mode=copy
        if [ "${INSTALL_MODE:-}" = "copy" ]; then
            run "rm -rf \"$target\""
            echo -e "  ${GREEN}✓${NC} removed $item (copy)"
        else
            echo -e "  ${YELLOW}skip${NC} $item (not a forge symlink — leaving in place)"
        fi
    fi
done

# 3. Forge metadata files
echo ""
echo "Removing forge metadata ..."
for meta_file in .forge-meta.json .forge-update-last-check; do
    target="$CLAUDE_DIR/$meta_file"
    if [ -e "$target" ]; then
        run "rm -f \"$target\""
        echo -e "  ${GREEN}✓${NC} $meta_file"
    fi
done

# 4. Shell aliases
if ! $KEEP_ALIASES; then
    echo ""
    echo "Cleaning shell aliases ..."
    for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
        [ -f "$rc" ] || continue
        if grep -q "^# Claude Code aliases" "$rc" 2>/dev/null; then
            if confirm "  Remove '# Claude Code aliases' block from $(basename "$rc")?"; then
                run "cp \"$rc\" \"$rc.forge-uninstall.bak\""
                # Remove the marker line + next 2 alias lines (cc, ccr) + trailing blank
                run "sed -i.tmp '/^# Claude Code aliases$/,/^alias ccr=/d' \"$rc\" && rm -f \"$rc.tmp\""
                echo -e "  ${GREEN}✓${NC} cleaned $(basename "$rc") (backup: $rc.forge-uninstall.bak)"
            fi
        fi
    done
fi

# 5. Restore from backup (optional)
if $RESTORE; then
    echo ""
    echo "Looking for ~/.claude.backup.* ..."
    latest_backup=$(ls -1dt "$HOME"/.claude.backup.* 2>/dev/null | head -1 || true)
    if [ -n "$latest_backup" ]; then
        echo "  Found: $latest_backup"
        if confirm "  Merge backup contents back into ~/.claude?"; then
            run "rsync -a --ignore-existing \"$latest_backup/\" \"$CLAUDE_DIR/\""
            echo -e "  ${GREEN}✓${NC} merged from $latest_backup"
            echo -e "  ${DIM}(backup directory left in place — delete manually when ready)${NC}"
        fi
    else
        echo -e "  ${YELLOW}no backup found${NC}"
    fi
fi

# 6. Summary
echo ""
echo -e "${GREEN}Uninstall complete.${NC}"
echo ""
echo "What remains in ~/.claude (your data, untouched):"
echo "  - history.jsonl, projects/, file-history/, cache/, ide/, metrics/, homunculus/, debug/, backups/"
echo ""
echo "To remove ~/.claude entirely (DESTRUCTIVE — wipes all Claude Code state):"
echo "  rm -rf ~/.claude"
echo ""
echo "To reinstall:"
echo "  cd ${REPO_PATH:-<claude-forge repo>} && ./install.sh"
