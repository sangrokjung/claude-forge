# Claude Code: Usage, Rate Limits & Extra Usage

Understanding how usage limits work in Claude Code and how to keep working when you hit them.

<table width="100%">
<tr>
<td><a href="../">← Back to Claude Code Best Practice</a></td>
<td align="right"><img src="../!/claude-jumping.svg" alt="Claude" width="60" /></td>
</tr>
</table>

---

## Overview

Claude Code on subscription plans (Pro, Max 5x, Max 20x) has usage limits that reset on a rolling window. Three built-in slash commands help you monitor and manage usage:

| Command | Description | Available To |
|---------|-------------|--------------|
| `/usage` | Check plan limits and rate limit status | Pro, Max 5x, Max 20x |
| `/extra-usage` | Configure pay-as-you-go overflow when limits are hit | Pro, Max 5x, Max 20x |
| `/cost` | Show token usage and spending for the current session | API key users |

---

## `/usage` — Check Your Limits

Shows your current plan's usage limits and rate limit status. Useful for checking how much capacity you have left before hitting a limit.

---

## `/extra-usage` — Keep Working Past Limits

The `/extra-usage` command configures **pay-as-you-go overflow billing** so Claude Code continues working seamlessly when you hit your plan's rate limits, instead of blocking you.

### How It Works

1. You hit your plan's rate limit (limits reset every 5 hours)
2. If extra usage is enabled with available funds, Claude Code continues without interruption
3. Overflow tokens are billed at **standard API rates**, separate from your subscription fee

### Setting It Up

The `/extra-usage` command in the CLI will guide you through configuration. You can also configure it on the web at **Settings > Usage** on claude.ai:

1. Enable extra usage
2. Add a payment method
3. Set a **monthly spending cap** (or choose unlimited)
4. Optionally add **prepaid funds** with auto-reload when balance drops below a threshold

### Key Details

| Detail | Value |
|--------|-------|
| Daily redemption limit | $2,000/day |
| Billing | Separate from subscription, at standard API rates |
| Limit reset window | Every 5 hours |

### Known Issue

As of February 2026, the `/extra-usage` CLI command is [undocumented](https://github.com/anthropics/claude-code/issues/12396) and may open a sign-in window without clear configuration options. Configuring through the **claude.ai web interface** is the more reliable path for now.

---

## `/cost` — Session Spending (API Users)

For users authenticating with an API key (not a subscription plan), `/cost` shows:

- Total cost for the current session
- API duration and wall time
- Token usage breakdown
- Code changes made

This command is not relevant for Pro/Max subscription users.

---

## Fast Mode and Extra Usage

Fast mode (`/fast`) uses Claude Opus 4.6 with faster output. It has a special billing relationship with extra usage:

- Fast mode usage is **always billed to extra usage** from the first token
- This applies even if you have remaining usage on your subscription plan
- Fast mode does not consume your plan's included rate limits

This means you need extra usage enabled and funded to use `/fast`.

---

## CLI Startup Flags

Two startup flags relate to usage budgets (API key users only, print mode):

| Flag | Description |
|------|-------------|
| `--max-budget-usd <AMOUNT>` | Maximum dollar amount for API calls before stopping |
| `--max-turns <NUMBER>` | Limit number of agentic turns |

See [CLI Startup Flags Reference](claude-cli-startup-flags.md) for the full list.

---

## Sources

- [Extra usage for paid Claude plans — Claude Help Center](https://support.claude.com/en/articles/12429409-extra-usage-for-paid-claude-plans)
- [Using Claude Code with your Pro or Max plan — Claude Help Center](https://support.claude.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan)
- [/extra-usage slash command is undocumented — GitHub Issue #12396](https://github.com/anthropics/claude-code/issues/12396)
- [Claude Code CLI Reference](https://code.claude.com/docs/en/cli-reference)
