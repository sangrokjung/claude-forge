# CLAUDE.md Guide — Memory, Hierarchy, @import

`CLAUDE.md` is the file Claude Code reads first, every session. Treat it like a runbook cover page: static, short, and packed with links to the things that actually change. This guide explains the 200-line rule, the load hierarchy, the `@import` syntax, and how `CLAUDE.md` relates to Auto Memory.

## The 200-Line Rule

Anthropic's official guidance is to keep `CLAUDE.md` under roughly 200 lines. The reason is practical: every line is loaded into context on every session, and long instruction files measurably degrade rule adherence. When Claude has to weigh 400 lines of project lore against a user prompt, the prompt loses.

A short `CLAUDE.md` also survives review. If teammates cannot read it in 60 seconds, they stop reading it, and drift begins. Use CLAUDE.md for what never changes — stack, golden rules, boundaries, memory policy — and push everything else into `.claude/rules/<topic>.md` pulled in via `@import`.

## Hierarchy (Load Order)

Claude walks the filesystem and stacks instruction files in this order:

| Level | Path | Loaded When |
|-------|------|-------------|
| Global | `~/.claude/CLAUDE.md` | Every session, any directory |
| Parent Dirs | `../CLAUDE.md` (recursive upward walk) | Session start, from cwd to `/` |
| Project | `<repo>/CLAUDE.md` | Working inside the repo |
| Local Override | `<repo>/CLAUDE.local.md` | Same session, gitignored personal copy |

Later files override earlier ones on the same topic, but all of them are active. This means a global rule in `~/.claude/CLAUDE.md` applies unless the project file explicitly says otherwise. `CLAUDE.local.md` is the escape hatch for "I want this setting but the team does not" — always gitignored.

## @import Syntax

Inside any `CLAUDE.md`, a line of the form `@relative/or/absolute/path.md` inlines that file at load time. The imported file is spliced in as if you had pasted its contents.

```markdown
## Golden Rules
@.claude/rules/golden-principles.md
@.claude/rules/verification.md

## Deploy
@~/qjc-office/dotclaude/reference/deploy-ref.md
```

Rules that keep imports sane:

- **No circular imports.** If `a.md` imports `b.md` and `b.md` imports `a.md`, Claude will either skip the second include or blow up — behavior is not guaranteed. Keep the graph a tree.
- **Prefer project-relative paths.** `@.claude/rules/foo.md` travels with the repo. `~/absolute/path.md` only works on your machine.
- **One concern per imported file.** If you find yourself importing a 500-line file, split it further. Small files are cheap; megafiles are what we are trying to avoid.
- **Imports count toward context.** `@import` does not magically compress — it just moves the text. A 200-line CLAUDE.md that imports four 300-line rule files is still a 1400-line instruction set at load time. Prune.

## Auto Memory vs CLAUDE.md

Claude Code ships two memory systems that look similar but serve opposite purposes:

| Dimension | CLAUDE.md | Auto Memory |
|-----------|-----------|-------------|
| Who writes it | Humans | Claude, during sessions |
| Lifecycle | Static, version-controlled | Dynamic, session-learned |
| Sharing | Team-shared via git | Local only (`~/.claude/agent-memory/`) |
| Content | Stack, rules, conventions | Per-agent corrections, preferences, observed patterns |
| Edit by hand? | Yes, encouraged | No — let the system manage it |
| Source of truth for | "How this project works" | "How Claude should behave with me, right now" |

Use `CLAUDE.md` when the fact is true for every teammate on every machine. Use Auto Memory when it is a personal preference Claude picked up from your corrections. If you catch yourself writing "remember that I prefer X" into `CLAUDE.md`, it probably belongs in Auto Memory instead.

## Extraction Pattern

When `CLAUDE.md` crosses 200 lines, extract topics rather than shrinking prose. Example:

**Before** (230 lines):

```markdown
# MyProject
## Stack
...
## Database Conventions
<60 lines on Supabase RLS, naming, migrations, seed data, backup strategy>
## Deploy
<40 lines on Vercel environments, preview URLs, rollback>
...
```

**After** (120 lines):

```markdown
# MyProject
## Stack
...
## Database Conventions
@.claude/rules/database.md
## Deploy
@.claude/rules/deploy.md
...
```

The extracted files live at `.claude/rules/database.md` and `.claude/rules/deploy.md` with the original content intact. `CLAUDE.md` drops below 200 lines, the rules stay discoverable, and new topics can be added without the file re-inflating.

## Template Usage

The starter template lives at `setup/CLAUDE.md.template`. Copy it into a new project's root, replace `{PROJECT_NAME}` with the actual name, and fill in the Stack and Project-Specific Conventions sections. `install.sh` can perform this substitution automatically when bootstrapping a new repo.

```bash
cp setup/CLAUDE.md.template ./CLAUDE.md
sed -i '' 's/{PROJECT_NAME}/my-app/g' ./CLAUDE.md
```

## Common Mistakes

- **Secrets in CLAUDE.md.** API keys, tokens, DB URLs. They end up in git history forever. Use `.env` and reference by variable name only.
- **Volatile state.** TODO lists, current blockers, sprint goals. These belong in `.claude/plan.md`, issues, or Auto Memory — not here.
- **Duplicating rules.** If a rule lives in `.claude/rules/foo.md`, do not also restate it in `CLAUDE.md`. Import it.
- **Ignoring the 200-line ceiling.** Past 200 lines, Claude starts ignoring the tail. You will notice rule drift before you notice the file length.
- **Project-wide rules in `CLAUDE.local.md`.** That file is gitignored. Teammates never see it. If it matters for everyone, put it in the shared `CLAUDE.md`.

## References

- Anthropic — [Claude Code memory documentation](https://docs.anthropic.com/en/docs/claude-code/memory)
- `docs/SKILLS-VS-COMMANDS.md` — when to use a skill vs a slash command alongside CLAUDE.md guidance
- `setup/CLAUDE.md.template` — starter template referenced throughout this guide
