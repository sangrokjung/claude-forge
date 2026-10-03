# Telegram Resume + Bridge

> Opt-in companion to Claude Code — resume dead sessions from Telegram, and
> optionally drive a live tmux session with your phone's keyboard.
>
> ⚠️ **Bridge forwards your Telegram messages as keystrokes into a live
> terminal.** Read [THREAT-MODEL.md](./THREAT-MODEL.md) before enabling it.

Two modes:

- **Resume** — session ended; tap a Telegram button to relaunch
  `claude --resume <uuid>` on your Mac.
- **Bridge** — session still alive; type `/tg` in the tmux pane and from
  that point your Telegram chat *is* the keyboard until you `/end` it.

Analogy: Resume is the restaurant pager — your dead order rings again.
Bridge is a remote-desktop keyboard — your PC never left, your fingers
did.

---

## Status / Security

| Item                        | Status                                     |
|-----------------------------|--------------------------------------------|
| Install default             | Bot files + launchd. Hooks are **opt-in**. |
| Enable hooks                | `./install.sh --with-hook`                 |
| Threat model                | [THREAT-MODEL.md](./THREAT-MODEL.md)       |
| Platform                    | macOS (launchd) — Linux requires manual systemd unit |
| Transport                   | long polling only, no inbound HTTP         |
| Allowlist                   | `TELEGRAM_CHAT_IDS`, enforced on every inbound update |
| Bridge owner check          | Only the chat that opened a bridge can inject into it |

**Token = keyboard.** The bot token is the only thing standing between an
attacker and your terminal while Bridge is active. See
[THREAT-MODEL.md](./THREAT-MODEL.md) for the full picture.

---

## Quick start

```bash
# 1) Create a bot via @BotFather, note the token.
#    Message the bot once, then:
curl "https://api.telegram.org/bot<TOKEN>/getUpdates" | jq '.result[0].message.chat.id'

# 2) Install (bot files + launchd, NO hooks yet):
cd scripts/telegram-resume
./install.sh

# 3) Fill in ~/.claude-forge/telegram-resume/.env — chmod 0600 is set for you.

# 4) Start the bot:
launchctl kickstart -k "gui/$UID/com.claudeforge.telegram-resume"
tail -f ~/.claude-forge/telegram-resume/logs/bot.out.log

# 5) Verify from Telegram: send '/sessions' to your bot.

# 6) ONLY after reading THREAT-MODEL.md — enable hooks for Resume alerts
#    and the /tg Bridge trigger:
./install.sh --with-hook
```

The hooks step is separate on purpose: once installed, every session-end
sends a project / branch / 100-char prompt preview to Telegram, and `/tg`
turns your Telegram chat into keyboard input.

---

## Install flags

| Flag                | Effect                                           |
|---------------------|--------------------------------------------------|
| *(none)*            | Copy bot files, create `.env` (mode `0600`), register launchd. **No hooks.** |
| `--with-hook`       | Also register `Stop` and `UserPromptSubmit` hooks in `settings.local.json`.* |
| `--no-daemon`       | Skip launchd registration.                       |
| `--uninstall`       | Unload + remove launchd service. (Hooks must be removed manually from `settings.local.json`.) |

\* If `~/.claude/settings.json` is a symlink (claude-forge's default), the
installer writes hooks to `settings.local.json` instead so your checkout
stays clean.

---

## Environment

Put these in `~/.claude-forge/telegram-resume/.env` (mode `0600`):

```ini
TELEGRAM_BOT_TOKEN=1234567890:ABCdef...
TELEGRAM_CHAT_IDS=987654321,112233445     # comma-separated allowlist
```

For the hooks to use the token, your Claude Code process also needs it
exported — the hooks read `TELEGRAM_BOT_TOKEN` from the environment, not
from `.env`. Put the export in your shell init or in a wrapper that
launches Claude Code. The token thus lives in two places; see
[THREAT-MODEL.md](./THREAT-MODEL.md) for the residual risk.

Optional:

| Variable                                | Default | Meaning                               |
|-----------------------------------------|---------|---------------------------------------|
| `TELEGRAM_POLL_TIMEOUT`                 | `25`    | long-poll seconds                     |
| `TELEGRAM_LIST_LIMIT`                   | `20`    | sessions per page                     |
| `TELEGRAM_BRIDGE_MAX_IDLE_MIN`          | `90`    | auto-close idle bridge                |
| `TELEGRAM_BRIDGE_MAX_BURST`             | `8`     | max forwarded entries per tick        |
| `TELEGRAM_RESUME_NOTIFY_MIN_TURNS`      | `2`     | skip Stop hook under N turns          |
| `TELEGRAM_LOG_LEVEL`                    | `INFO`  |                                       |

---

## What the Stop hook sends to Telegram

When `--with-hook` registers it, the Stop hook sends a message like:

> ✅ *projectname* 세션 종료 · `branch` \
> *"first 100 chars of the last user prompt"* \
> 12턴 · `abcd1234`

Specifically: project name (`basename` of cwd), git branch (last segment),
turn count, first 8 chars of session UUID, and up to **100 characters of
the last user message** in the transcript. If that preview is sensitive
for your work, don't pass `--with-hook`, or edit
`hooks/telegram-resume-notify.sh` to omit the quoted preview.

---

## File layout

```
scripts/telegram-resume/
├── README.md                                   # this doc (English primary)
├── THREAT-MODEL.md                             # read before --with-hook
├── bot.py                                      # long-polling bot (Resume + Bridge)
├── bridge.py                                   # bridge state machine
├── keyboard.py                                 # inline keyboard builders
├── sessions.py                                 # session metadata loader
├── executor.sh                                 # resume → tmux
├── notify.sh                                   # one-shot Telegram sender
├── install.sh                                  # installer
├── requirements.txt                            # requests
├── .env.example                                # env template
└── launchd/
    └── com.claudeforge.telegram-resume.plist   # launchd template (macOS)

hooks/
├── telegram-resume-notify.sh                   # Stop hook (opt-in via --with-hook)
└── handoff-telegram.sh                         # UserPromptSubmit hook (/tg trigger)
```

---

## Callback routing

| callback_data              | Action                                       |
|----------------------------|----------------------------------------------|
| `cf:resume:latest`         | Confirmation screen for most recent session  |
| `cf:resume:<uuid>`         | Confirmation screen for a specific session   |
| `cf:exec:r:<short>`        | `claude --resume <uuid>` via tmux            |
| `cf:exec:f:<short>`        | `--fork-session`                             |
| `cf:exec:rc:<short>`       | `--remote-control`                           |
| `cf:list:page=N`           | Pagination                                   |
| `cf:list:refresh`          | Refresh list                                 |
| `cf:cancel`                | Dismiss confirmation                         |
| `cf:settings`              | Settings dialog                              |

`<short>` is the first 8 chars of the full UUID — the 64-byte Telegram
callback limit forces a prefix, and the bot resolves it back to the full
UUID from the session index before executing.

---

## Bridge mode — how it works

### 1) Mac — trigger

Inside a Claude Code session that is running **inside tmux**, type one of:

```
/tg
/handoff-tg
>>tg
```

The `UserPromptSubmit` hook intercepts it and:

1. Writes `~/.claude-forge/telegram-resume/state/bridge.json`.
2. Sends a "🔌 Bridge started" message to the first allowlisted chat.
3. Exits with code 2 so the prompt is NOT delivered to Claude.

The Claude process keeps running — MCP servers, memory context, tool
state are all preserved.

### 2) Telegram — operate

In your chat with the bot:

- **Plain text** → `tmux send-keys` into the Mac pane (= Claude input).
  Only the chat that opened the bridge can inject; a second allowlisted
  chat gets *"this bridge is owned by another chat — injection refused."*
- `/bridge` or `/status` → current bridge state.
- `/end` → stop the bridge; Mac keyboard resumes.
- `/health` → diagnostic summary.
- `/sessions`, `/resume` — Resume features (work regardless of Bridge).

### 3) Mac — return to the keyboard

Two paths:

- **A. From Mac tmux:** `/tg-end`, `/end-tg`, or `/handoff-end`. Hook
  deletes the state file and pings Telegram that control returned.
- **B. From Telegram:** `/end`.

### 4) Auto-close conditions

- The owning Claude session's `Stop` hook fires (session ended).
- 90 min idle (`TELEGRAM_BRIDGE_MAX_IDLE_MIN`).
- `bridge.tick` notices the jsonl or tmux session vanished.

### 5) Multi-line messages

A Telegram message with newlines is sent through
`tmux load-buffer` + `paste-buffer -p`, i.e. with bracketed-paste markers
(`ESC[200~ … ESC[201~`). Claude Code's TUI (React Ink) treats the whole
block as one input instead of splitting on each newline. Line-buffered
tools that ignore BPM may still treat each newline as Enter — in that
case send one line at a time.

### Bridge state file

```json
{
  "active": true,
  "session_uuid": "9e85e278-...",
  "jsonl_path": "/Users/.../9e85e278-....jsonl",
  "tmux_target": "claude-9e85e278:0.0",
  "chat_id": "987654321",
  "project_name": "Darwin",
  "git_branch": "feature/v1.1",
  "started_at": "2026-05-17T05:30:00Z",
  "last_activity_at": "2026-05-17T05:32:11Z",
  "jsonl_size_at_start": 524288
}
```

The bot polls this file's mtime each cycle; a change triggers a reload.
Bot restarts recover the active bridge, and `jsonl_size_at_start` prevents
replaying old assistant turns.

---

## Running without launchd

```bash
cd ~/.claude-forge/telegram-resume
set -a; . ./.env; set +a
./venv/bin/python bot.py
```

---

## Dry-run verification

```bash
# 1) Session indexer
python3 sessions.py

# 2) Keyboard rendering (JSON)
python3 keyboard.py

# 3) executor.sh — no tmux side effects
DRY_RUN=1 ./executor.sh resume <session-uuid>

# 4) Stop hook — no outbound send with empty env
echo '{"session_id":"...","cwd":"/tmp","transcript_path":"..."}' \
  | TELEGRAM_BOT_TOKEN= TELEGRAM_CHAT_IDS= \
    ../../hooks/telegram-resume-notify.sh

# 5) Unit tests
python3 -m unittest discover -s tests -v
```

---

## Uninstall

```bash
./install.sh --uninstall
```

Unloads and removes the launchd plist. The Stop / UserPromptSubmit hook
entries (if you had passed `--with-hook`) must be removed manually from
`~/.claude/settings.local.json` — grep for `telegram-resume-notify.sh`
and `handoff-telegram.sh`.

---

## Known limitations

- macOS launchd only. Linux users need to write a systemd unit by hand.
- Session resume runs on the machine the bot is on; multi-machine routing
  is out of scope.
- Uses `tmux` panes, not iTerm2 native panes; `claude --tmux`
  compatibility is a separate problem.

---

## 한국어 요약

- 두 모드 — Resume(죽은 세션 다시 띄우기) + Bridge(살아있는 tmux 세션을 폰 키보드로 조작)
- Bridge는 설계상 **원격 키보드 주입**이다. 토큰 유출 = 터미널 키보드 접근으로 간주.
  활성화 전에 반드시 [THREAT-MODEL.md](./THREAT-MODEL.md)를 읽을 것.
- hooks는 기본 비활성 (`--with-hook`로 명시적 opt-in)
- `.env`는 설치 시 `0600`으로 강제
- Bridge 활성 중에는 bridge를 연 채팅만 주입 가능 (교차 채팅 주입 차단)
- Stop hook은 Telegram으로 프로젝트명 / 브랜치 / 최근 유저 메시지 100자 preview를 전송
- 원래 Korean README는 git history에서 확인 가능 (`git log -- README.md`)
