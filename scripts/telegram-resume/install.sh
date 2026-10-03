#!/usr/bin/env bash
#
# install.sh — install the Telegram resume bot to ~/.claude-forge/telegram-resume/
# and (optionally) wire hooks and the launchd service.
#
# Hooks are OPT-IN: without --with-hook, the Stop + UserPromptSubmit hooks
# that register Bridge into your Claude Code sessions are NOT installed.
# This keeps the blast radius narrow — Bridge is remote keyboard input
# into a live session by design, so you should opt in deliberately.
#
# Usage:
#   ./install.sh                # bot files + launchd, no hooks
#   ./install.sh --with-hook    # also register Stop + UserPromptSubmit hooks
#   ./install.sh --no-daemon    # skip launchd registration
#   ./install.sh --uninstall    # remove launchd service + hook entry
#

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET_DIR="${TELEGRAM_RESUME_NOTIFY_DIR:-$HOME/.claude-forge/telegram-resume}"
LAUNCHD_LABEL="com.claudeforge.telegram-resume"
PLIST_PATH="$HOME/Library/LaunchAgents/${LAUNCHD_LABEL}.plist"
SETTINGS_JSON="$HOME/.claude/settings.json"

INSTALL_HOOK=0
INSTALL_DAEMON=1
UNINSTALL=0

for arg in "$@"; do
  case "$arg" in
    --with-hook) INSTALL_HOOK=1 ;;
    --no-hook)
      # Previously the default was opt-out; honour --no-hook as a no-op for
      # anyone still passing it from scripts/docs.
      INSTALL_HOOK=0
      ;;
    --no-daemon) INSTALL_DAEMON=0 ;;
    --uninstall) UNINSTALL=1 ;;
    --help|-h)
      sed -n '1,24p' "$0"
      exit 0
      ;;
    *)
      echo "unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

c_blue()  { printf '\033[34m%s\033[0m\n' "$*"; }
c_green() { printf '\033[32m%s\033[0m\n' "$*"; }
c_yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }
c_red()   { printf '\033[31m%s\033[0m\n' "$*"; }

require() {
  command -v "$1" >/dev/null 2>&1 || { c_red "missing: $1"; exit 1; }
}

uninstall() {
  c_yellow "→ Stopping & unloading launchd service"
  if [[ -f "$PLIST_PATH" ]]; then
    launchctl unload -w "$PLIST_PATH" 2>/dev/null || true
    rm -f "$PLIST_PATH"
    c_green "✓ Removed ${PLIST_PATH}"
  fi
  c_yellow "→ Leaving ${TARGET_DIR} in place (delete manually if desired)"
  c_yellow "→ NOTE: Stop hook entry in ${SETTINGS_JSON} (if any) was not auto-removed."
  c_green "✓ Uninstall complete"
}

if (( UNINSTALL )); then
  uninstall
  exit 0
fi

c_blue "=== claude-forge · Telegram resume bot installer ==="
echo "Source:   $REPO_DIR"
echo "Target:   $TARGET_DIR"
echo "Settings: $SETTINGS_JSON"
echo

require python3
require curl
command -v tmux >/dev/null 2>&1 || c_yellow "⚠️  tmux not found — install with 'brew install tmux' to use executor"

mkdir -p "$TARGET_DIR" "$TARGET_DIR/state"
cp -f "$REPO_DIR/sessions.py" "$TARGET_DIR/"
cp -f "$REPO_DIR/keyboard.py" "$TARGET_DIR/"
cp -f "$REPO_DIR/bridge.py"   "$TARGET_DIR/"
cp -f "$REPO_DIR/bot.py"      "$TARGET_DIR/"
cp -f "$REPO_DIR/executor.sh" "$TARGET_DIR/"
cp -f "$REPO_DIR/notify.sh"   "$TARGET_DIR/"
cp -f "$REPO_DIR/requirements.txt" "$TARGET_DIR/"
chmod +x "$TARGET_DIR/executor.sh" "$TARGET_DIR/notify.sh"
c_green "✓ Copied bot files to ${TARGET_DIR}"

if [[ ! -f "$TARGET_DIR/.env" ]]; then
  cp -f "$REPO_DIR/.env.example" "$TARGET_DIR/.env"
  chmod 600 "$TARGET_DIR/.env"
  c_yellow "✓ Created ${TARGET_DIR}/.env (0600) — EDIT IT before starting the bot."
else
  # Tighten perms even on existing files — the token must stay owner-only
  # regardless of umask when the file was first created.
  chmod 600 "$TARGET_DIR/.env"
  c_green "✓ Existing ${TARGET_DIR}/.env preserved (perms tightened to 0600)"
fi

c_blue "→ Installing Python deps to ${TARGET_DIR}/venv"
if [[ ! -d "$TARGET_DIR/venv" ]]; then
  python3 -m venv "$TARGET_DIR/venv"
fi
"$TARGET_DIR/venv/bin/pip" install --quiet --upgrade pip
"$TARGET_DIR/venv/bin/pip" install --quiet -r "$TARGET_DIR/requirements.txt"
c_green "✓ Installed Python deps"

if (( INSTALL_HOOK )); then
  # Claude-forge's own `install.sh` symlinks ~/.claude/settings.json into the
  # repo checkout, so writing to it would dirty the checkout and later block
  # `git pull`.  Register hooks in settings.local.json instead — Claude Code
  # overlays local settings on top of the shared file.
  SETTINGS_LOCAL="$(dirname "$SETTINGS_JSON")/settings.local.json"
  WRITE_TARGET="$SETTINGS_JSON"
  if [[ -L "$SETTINGS_JSON" ]]; then
    WRITE_TARGET="$SETTINGS_LOCAL"
    c_yellow "ℹ️  ${SETTINGS_JSON} is a symlink — writing hooks to ${WRITE_TARGET} instead"
  fi

  c_blue "→ Registering Stop + UserPromptSubmit hooks in ${WRITE_TARGET}"
  HOOKS_DIR="$(cd "$REPO_DIR/../../hooks" && pwd)"
  STOP_HOOK="${HOOKS_DIR}/telegram-resume-notify.sh"
  PROMPT_HOOK="${HOOKS_DIR}/handoff-telegram.sh"

  mkdir -p "$(dirname "$WRITE_TARGET")"
  if [[ ! -f "$WRITE_TARGET" ]]; then
    echo '{}' > "$WRITE_TARGET"
  fi

  python3 - "$WRITE_TARGET" "$STOP_HOOK" "$PROMPT_HOOK" <<'PY'
import json, sys, pathlib

settings_path = pathlib.Path(sys.argv[1])
stop_cmd, prompt_cmd = sys.argv[2], sys.argv[3]

# Guard: if this is still a symlink for any reason, resolve + warn rather
# than silently writing through it (the shared file would get polluted).
if settings_path.is_symlink():
    print(f"⚠️  Refusing to write through symlink: {settings_path}", file=sys.stderr)
    sys.exit(3)

data = json.loads(settings_path.read_text() or "{}")
hooks = data.setdefault("hooks", {})


def register(event_name: str, command: str, timeout: int) -> str:
    bucket = hooks.setdefault(event_name, [])
    for entry in bucket:
        for h in entry.get("hooks", []):
            if h.get("command") == command:
                return "already-present"
    bucket.append({
        "hooks": [{"type": "command", "command": command, "timeout": timeout}]
    })
    return "added"


print("Stop:", register("Stop", stop_cmd, 10))
print("UserPromptSubmit:", register("UserPromptSubmit", prompt_cmd, 5))
settings_path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
PY
  c_green "✓ Hooks registered in ${WRITE_TARGET}"
fi

if (( INSTALL_DAEMON )); then
  c_blue "→ Installing launchd service: ${LAUNCHD_LABEL}"
  mkdir -p "$HOME/Library/LaunchAgents"

  PYTHON_BIN="$TARGET_DIR/venv/bin/python"
  LOG_DIR="$TARGET_DIR/logs"
  mkdir -p "$LOG_DIR"

  PLIST_SRC="$REPO_DIR/launchd/com.claudeforge.telegram-resume.plist"
  if [[ -f "$PLIST_SRC" ]]; then
    sed \
      -e "s|@@PYTHON@@|${PYTHON_BIN}|g" \
      -e "s|@@BOT@@|${TARGET_DIR}/bot.py|g" \
      -e "s|@@ENV_FILE@@|${TARGET_DIR}/.env|g" \
      -e "s|@@WORKING_DIR@@|${TARGET_DIR}|g" \
      -e "s|@@LOG_DIR@@|${LOG_DIR}|g" \
      "$PLIST_SRC" > "$PLIST_PATH"
    c_green "✓ Wrote ${PLIST_PATH}"
    launchctl unload -w "$PLIST_PATH" 2>/dev/null || true
    launchctl load -w "$PLIST_PATH"
    c_green "✓ Loaded launchd service. Check: launchctl list | grep ${LAUNCHD_LABEL}"
  else
    c_yellow "⚠️  ${PLIST_SRC} not found — daemon skipped"
  fi
fi

c_blue "=== Next steps ==="
echo "1) Edit env:    \$EDITOR ${TARGET_DIR}/.env"
echo "2) Restart bot: launchctl kickstart -k gui/\$UID/${LAUNCHD_LABEL}"
echo "3) Test:        send '/sessions' to your bot"
echo "4) Logs:        tail -f ${TARGET_DIR}/logs/bot.out.log"
if (( ! INSTALL_HOOK )); then
  echo
  c_yellow "Note: Stop + UserPromptSubmit hooks are NOT installed."
  c_yellow "      Resume alerts and the /tg bridge trigger need them."
  c_yellow "      Rerun with --with-hook once you've read docs/THREAT-MODEL.md."
fi
echo
c_green "Done."
