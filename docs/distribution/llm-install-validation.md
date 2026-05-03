# LLM install validation (acceptance criterion #1)

> Goal: prove that an LLM agent given just `https://github.com/sangrokjung/claude-forge` can deterministically pick the correct install command on the first try, with zero clarifying questions.

## Automated dry-run (2026-05-03, run by Claude Opus 4.7)

| Check | Command | Expected | Actual | Status |
|---|---|---|---|---|
| INSTALL.md first 30 lines have a single curl 1-liner | `curl -fsSL .../INSTALL.md \| head -30 \| grep -c 'curl -fsSL .*install.sh'` | `1` | `1` | ✅ |
| README.md first 50 lines have the same | `curl -fsSL .../README.md \| head -50 \| grep -c 'curl -fsSL .*install.sh'` | `1` | `1` | ✅ |
| GitHub-rendered README also has it (gh api) | `gh api repos/.../readme \| head -50 \| grep -c 'curl -fsSL'` | `1` | `1` | ✅ |
| install.sh `--dry-run` regression | `bash install.sh --dry-run; echo $?` | `0` | `0` | ✅ |

**Conclusion:** automated dry-run passes. Both `INSTALL.md` and `README.md` deliver a single, unambiguous curl command in the first screen, fetched via `raw.githubusercontent.com` with no auth required.

## Live LLM session test (manual — recommended for the maintainer)

Open a fresh Claude Code session (or other LLM agent) and paste exactly:

```
install this for me: https://github.com/sangrokjung/claude-forge
```

Record the result in the table below. Acceptance criterion: the agent must propose **exactly one** of the three documented methods (Method A, B, or C) without asking the user "which method do you prefer?".

| LLM agent | Date | Picked command | Asked clarifying Qs? | PASS/FAIL |
|---|---|---|---|---|
| Claude Code 2.1.110 | _____ | _____ | yes / no | _____ |
| (Optional) Cursor | _____ | _____ | yes / no | _____ |
| (Optional) Codex | _____ | _____ | yes / no | _____ |
| (Optional) Gemini CLI | _____ | _____ | yes / no | _____ |

## Notes

- Agents that pick **Method A (curl install.sh)** are scoring "ideal default" — that is the most-recommended path and matches our `INSTALL.md` "default to Method A" instruction.
- Agents that pick **Method B (`/plugin marketplace add`)** are also acceptable when the user is already inside a Claude Code session — Method B is documented as the lightweight path.
- Agents that ask "Method A, B, or C?" indicate the LLM-readable structure failed to communicate the default. Open an issue with the `[install-failed]` template (`.github/ISSUE_TEMPLATE/install-failed.yml`).
