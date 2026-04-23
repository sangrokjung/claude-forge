# Skills vs Commands: The claude-forge v3.0 Hybrid Policy

> **TL;DR** — Put **auto-invocable knowledge and repeatable workflows** under `skills/<name>/SKILL.md`. Put **explicit side-effect actions that need precise user timing** under `commands/*.md`. If it can also be bundled with helpers and references, it belongs in `skills/`. When in doubt, start as a skill; promote to a command only when the action has real blast radius.

---

## The Core Distinction

Anthropic's 2026 guidance (reinforced in the official Skills and Slash Commands docs) treats the two surfaces as **complementary, not interchangeable**. claude-forge v3.0 adopts the same contract:

| Dimension | `skills/<name>/SKILL.md` | `commands/*.md` |
|-----------|--------------------------|-----------------|
| **Invocation** | Auto (description trigger matches user intent) | Explicit (`/name` typed by the user) |
| **Side effects** | Minimal — read-biased, analysis, plan generation | Expected — commit, push, deploy, send |
| **`disable-model-invocation`** | `false` (default — let Claude discover it) | `true` (recommended — only fire on user command) |
| **Bundled scripts / refs** | Yes (`helpers/`, `references/`, `examples/`) | No — single flat `.md` |
| **Re-use pattern** | High — a knowledge base loaded many times | Low — a one-off flow triggered at decision points |
| **Size budget** | ≤ 500 lines in `SKILL.md`; overflow goes to `references/` | ≤ 200 lines per `commands/*.md` |
| **Best for** | "How should I think about X?" | "Do X right now." |

---

## When to Write a Skill

Pick `skills/` when **any** of the following are true:

- **The content is reusable knowledge or a repeatable multi-step workflow** — e.g. `skills/build-system/` detects a project's build tool and runs it; `skills/eval-harness/` drives a formal evaluation loop end-to-end.
- **You want Claude to auto-discover it** via description matching, not wait for a typed slash command — e.g. `skills/continuous-learning-v2/` observes sessions through hooks and improves without a user prompt.
- **You need bundled helpers or references** that the flow loads on demand — e.g. `skills/security-pipeline/` ships pre-commit pipeline steps with linked references, and `skills/prompts-chat/` packages prompt templates alongside the entry point.
- **Side effects are minimal or read-biased** — the skill reads, analyzes, or proposes, and only writes artifacts inside its own sandbox (e.g. `skills/session-wrap/` produces a summary file; `skills/strategic-compact/` suggests compaction rather than executing it destructively).
- **The surface is an orchestration fabric, not a single action** — e.g. `skills/team-orchestrator/`, `skills/skill-factory/`, `skills/manage-skills/` compose other skills and agents.
- **Knowledge is layered** — the top-level `SKILL.md` stays light, with deeper material in `references/` so token budget scales with depth, not breadth (matches `skills/cache-components/`, `skills/verification-engine/`).

---

## When to Write a Command

Pick `commands/` when **any** of the following are true:

- **There are real, user-visible side effects** — commit, push, merge, deploy, notify, or mutate shared state. `commands/commit-push-pr.md` commits, pushes, opens a PR, optionally merges, and fires MCP notifications; that timing must be user-driven.
- **Timing matters and the user is the best judge of "now"** — e.g. `commands/quick-commit.md`, `commands/pull.md`, `commands/sync.md`, `commands/worktree-start.md` should only fire when the user explicitly asks.
- **The flow is a single-shot pipeline**, not a knowledge base — e.g. `commands/auto.md`, `commands/handoff-verify.md`, `commands/verify-loop.md`, `commands/build-fix.md` execute a short, deterministic sequence and exit.
- **It's a thin entry point or shortcut** into tooling the user already knows by name — e.g. `commands/plan.md`, `commands/tdd.md`, `commands/code-review.md`, `commands/checkpoint.md`.
- **You want to suppress model auto-invocation** — `disable-model-invocation: true` in the command frontmatter prevents Claude from firing a destructive flow without the user typing it.
- **The action takes arguments via `argument-hint`** — e.g. `commands/commit-push-pr.md` declares `argument-hint: [commit message] [--merge|--squash|--rebase] [...]`. That handshake belongs to commands.

---

## The Gray Zone

Real cases where the line blurs, and how claude-forge resolves them:

- **`debugging-strategies`** — currently `commands/debugging-strategies/SKILL.md`. It is a **reference knowledge base**, auto-useful whenever a bug appears, with no side effects. **Resolution (v3.0):** migrate to `skills/debugging-strategies/`.
- **`stride-analysis-patterns`, `security-compliance`** — directory-form entries under `commands/` that wrap threat modeling and compliance references. They are re-read across sessions and carry supplementary references. **Resolution (v3.0):** migrate to `skills/`.
- **`evaluating-code-models`, `evaluating-llms-harness`** — evaluation harness guides with benchmark references. Already structured like skills (SKILL.md + `references/`). **Resolution (v3.0):** migrate to `skills/`.
- **`/plan` vs `skills/cc-dev-agent`** — `/plan` is a **command** because the user times when planning begins on their branch. `skills/cc-dev-agent/` is a **skill** because writing CLAUDE.md/spec/plan is reusable know-how any project can lean on.
- **`/commit-push-pr` could bundle strategies into `helpers/`** — but staying a single-file command is correct: the user always invokes it explicitly, and the side effects are large.

**Rule of thumb:** if you find yourself wanting a `references/` subtree, it's a skill. If the first thing users do is type `/name`, it's a command.

---

## Migration from v2.1 (Summary)

Eight directory-form entries currently living under `commands/` will move to `skills/` in v3.0. They already match the skill shape (`<dir>/SKILL.md` plus optional `references/`).

| v2.1 location | v3.0 location |
|---------------|---------------|
| `commands/debugging-strategies/` | `skills/debugging-strategies/` |
| `commands/dependency-upgrade/` | `skills/dependency-upgrade/` |
| `commands/evaluating-code-models/` | `skills/evaluating-code-models/` |
| `commands/evaluating-llms-harness/` | `skills/evaluating-llms-harness/` |
| `commands/extract-errors/` | `skills/extract-errors/` |
| `commands/security-compliance/` | `skills/security-compliance/` |
| `commands/stride-analysis-patterns/` | `skills/stride-analysis-patterns/` |
| `commands/summarize/` | `skills/summarize/` |

Backward-compatibility symlinks under `commands/` will be maintained for **one year**. Full step-by-step instructions live in [`MIGRATION.md`](../MIGRATION.md) (T8).

---

## Naming Conventions

- **Skills** — kebab-case, domain- or capability-oriented. Prefer plural / topic nouns that describe a body of knowledge: `debugging-strategies`, `stride-analysis-patterns`, `cache-components`, `verification-engine`, `team-orchestrator`.
- **Commands** — kebab-case, action-oriented. Prefer verb-first names the user is happy to type: `commit-push-pr`, `build-fix`, `quick-commit`, `worktree-start`, `handoff-verify`.

Avoid collisions: a skill and command must not share a base name. The installer warns on conflicts.

---

## Frontmatter Standards

### `skills/<name>/SKILL.md`

```yaml
---
name: my-skill
description: >-
  What this skill does + the trigger phrases Claude should match on
  (keep keywords concrete so auto-invocation works).
disable-model-invocation: false   # default; omit to let Claude discover it
subagent: false                    # true only if the skill delegates to a subagent
allowed-tools: ["Read", "Grep", "Glob", "Bash"]
---
```

### `commands/*.md`

```yaml
---
name: my-command
description: One-line summary of what this command does.
argument-hint: "[arg] [--flag]"
model: sonnet                      # or opus/haiku per task sandwich
allowed-tools: ["Bash(git:*)", "Read", "Grep"]
disable-model-invocation: true     # recommended for commands with side effects
---
```

---

## Authoring Checklist

Before you commit a new surface, run the list:

- [ ] **Side effects?** Writes to git, network, or shared systems → **command**.
- [ ] **Auto-invocable knowledge?** No side effects, Claude should pick it up → **skill**.
- [ ] **Needs `references/` or `helpers/`?** → **skill**.
- [ ] **User times the action?** → **command** with `disable-model-invocation: true`.
- [ ] **Name is unique** across both `skills/` and `commands/`.
- [ ] **Size budget** respected (≤ 500 lines SKILL.md + refs, ≤ 200 lines command).
- [ ] **Frontmatter** matches the standard above — `description` is trigger-rich for skills, `argument-hint` is present for commands.
- [ ] **Entry in `CONTRIBUTING.md` or README table** if the surface is externally visible.

---

## References

- Anthropic Skills docs — https://code.claude.com/docs/en/skills
- Anthropic Slash Commands docs — https://code.claude.com/docs/en/slash-commands
- [`CONTRIBUTING.md`](../CONTRIBUTING.md) — contribution workflow and coding standards
- [`MIGRATION.md`](../MIGRATION.md) — v2.1 → v3.0 migration details (T8)
