# Threat Model — Telegram Resume + Bridge

> Read this **before** running `./install.sh --with-hook`.
> Bridge is remote keyboard input into a live terminal **by design**.

---

## TL;DR

If an attacker gets your Telegram bot token, they can type whatever they
want into a live Claude Code session running on your Mac — not just chat
with the bot. Treat the token like an SSH key.

- The bot runs on **your machine** and polls Telegram.
- When Bridge is active, every text message from any allowlisted chat is
  forwarded as keystrokes to the owning session's tmux pane.
- The allowlist (`TELEGRAM_CHAT_IDS`) is the only thing between an attacker
  and your keyboard. The bot token is what lets anyone *be* an allowlisted
  chat.

---

## Trust boundaries

| Boundary                              | What crosses it            | What enforces it                      |
|---------------------------------------|----------------------------|---------------------------------------|
| Telegram ↔ bot process                | bot token (secret)         | `.env` file mode `0600`               |
| Allowlisted chat → bot process        | user messages / callbacks  | `TELEGRAM_CHAT_IDS` allowlist         |
| Bot process → live Claude session     | keystrokes via `tmux`      | `sender_chat_id == bridge.state.chat_id` |
| Bot process → disk                    | state file, logs           | `~/.claude-forge/telegram-resume/`    |

**The weakest link is the bot token.** A compromised token means the attacker
can impersonate your chat to the bot and inject keystrokes into any live
Bridge. Rotate it via @BotFather if there is any doubt.

---

## Assets

- **The bot token** (`TELEGRAM_BOT_TOKEN`) — a shared secret with Telegram.
  Compromise = anyone can send messages that your bot process will trust as
  coming from the allowlist (assuming they also know a chat id, which is
  effectively public — guessing one is a 12-digit integer search).
- **Live Claude Code sessions** on the Mac that is running the bot. Any
  session that was active-handed-off to Bridge is reachable while Bridge
  is active.
- **Transcript previews** — the Stop hook sends the project name, the
  branch, the turn count, and the first ~100 chars of the last user prompt
  to Telegram so you can see what finished. If any of that is sensitive,
  turn the Stop hook off.

---

## Attacker model

We consider two concrete attackers:

1. **A thief with your phone.** The Telegram app on your phone is already
   authenticated — they can tap any message into the bot and (if Bridge is
   active) have it typed into your Mac terminal. Mitigation is your phone
   lock. We cannot defend against an unlocked, authenticated phone.
2. **Someone who exfiltrates the bot token.** The token lives in `.env`
   (`0600`) and in the Claude Code process environment while hooks run.
   Anyone with the token can poll `getUpdates`, impersonate your chat, and
   inject keystrokes while Bridge is active.

Out of scope: a local attacker who already has root on your Mac. At that
point every secret the bot touches is theirs anyway.

---

## What Bridge CAN do once active

- Type arbitrary text into Claude Code's input via `tmux send-keys`.
- With a multi-line message, paste as bracketed-paste (Claude Code treats
  it as a single prompt rather than a sequence of Enters).
- The injected text goes through Claude's permission flow — so file edits,
  shell commands, and MCP tool calls still need whatever approval the user
  normally gives. **It can send `yes` to those prompts.**

## What Bridge canNOT do

- Open a new Claude Code session on its own (requires `/sessions` + a
  `cf:exec:*` tap, which runs `executor.sh` through tmux).
- Access files outside what Claude Code can access.
- Bypass OS-level approvals.

---

## Mitigations in place

- `.env` is created `0600` and tightened on every install.
- Hooks are **opt-in** (`--with-hook`) — the default install does not wire
  the `/tg` trigger or the Stop-hook forward.
- The bot refuses messages from any chat outside `TELEGRAM_CHAT_IDS`.
- When Bridge is active, only `bridge.state.chat_id` can inject — a second
  allowlisted chat cannot type into someone else's bridge.
- `getUpdates` and API errors are logged with the token redacted so the
  `requests.RequestException` URL never ends up in `bot.err.log`.
- The bot uses long polling. There is no inbound HTTP endpoint on your
  machine.
- Bridge auto-closes on tmux disappearance, jsonl deletion, 90 min idle,
  and Claude's `Stop` hook.

---

## Residual risks you should know about

- **Token in process env.** The hooks (`handoff-telegram.sh`,
  `telegram-resume-notify.sh`) read `TELEGRAM_BOT_TOKEN` from the Claude
  Code process environment — you must `export` it in your shell init or
  wrapper. Anyone who can read your shell env (another local user, a
  compromised process in your user) can read the token even though `.env`
  is `0600`.
- **Transcript peek in Stop hook.** Project name, branch, and up to 100
  chars of the last user prompt are sent to Telegram when a session ends.
  Skip `--with-hook` or edit `telegram-resume-notify.sh` to omit the
  preview if your prompts are sensitive.
- **Allowlist bypass via token.** The allowlist is enforced inside the bot
  process. Someone with the token can poll `getUpdates` directly without
  going through your bot — but they cannot inject keystrokes that way, only
  send messages to the chat. They CAN, however, impersonate your chat
  towards *your* bot process by sending from the same chat id you listed.
  In practice, token loss = keyboard access, full stop.

---

## Operational checklist

- [ ] `~/.claude-forge/telegram-resume/.env` is mode `0600`
      (`stat -f '%p' ~/.claude-forge/telegram-resume/.env | tail -c 4`
       should print `600`).
- [ ] `TELEGRAM_CHAT_IDS` contains ONLY ids you control.
- [ ] You rotated the bot token after any device loss / repo mishap.
- [ ] You know how to kill the daemon fast:
      `launchctl bootout gui/$UID/com.claudeforge.telegram-resume`.
- [ ] You read what the Stop hook sends (see `hooks/telegram-resume-notify.sh`)
      and are OK with that going to Telegram.
