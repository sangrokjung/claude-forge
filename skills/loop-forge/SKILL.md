---
name: loop-forge
description: |
  Turn a one-line description of a repetitive task into a reusable, self-guarding
  slash command. loop-forge diagnoses the task into one of 5 loop shapes (Batch /
  Pipeline / Refine / Watch / Explore), interviews for the blanks, and auto-injects
  two safety devices the user didn't know they needed — an independent verifier
  (maker ≠ checker) and a hardstop (a budget/count/cooldown ceiling) — then previews
  the result and stamps it as a `/command` they can run forever. Use when the user
  says "/loop", "/loop-forge", "/make-it-loop", "automate this", "make this
  repeatable", "turn this into a command", "do this for all 100 items", "do X every
  time Y happens", "generate several and pick the best", or otherwise wants to
  capture a recurring task as a reusable slash command instead of re-typing the
  prompt by hand. Works in any language: it interviews the user and writes the
  stamped command in the user's own language. Non-goal — it does not schedule
  unattended runs (launchd/cron) or publish externally on its own; it stamps the
  reusable command and stops there.
---

# loop-forge — stamp a guarded, reusable loop (`/loop-forge`)

> Picture an engraving shop. A customer who can't engrave walks in and just
> *describes* the seal they keep needing — "I want to do this over and over."
> The artisan ① recognizes which of 5 standard molds (loop shapes) it is, ② asks
> what letters to cut (the blanks), ③ cuts them into a proven mold, ④ automatically
> fits a "misprint detector" (the verifier) and an "out-of-ink stop" (the hardstop),
> ⑤ pulls one test impression to show the customer, and ⑥ once they approve, hands
> back a reusable `/command` they can stamp again any time — the same in Claude Code
> and in any other agent via a paste-able prompt.

## What this tool actually does

Someone who doesn't code can't author a reusable `/command` that makes an AI repeat
a task reliably. loop-forge closes that gap. It takes a vague one-liner and stamps
it into a **reusable slash command**, while automatically attaching the two safety
devices a non-developer doesn't even know to ask for:

- **Verifier (maker ≠ checker)** — the loop's output is re-checked in a pass that is
  *separate* from the pass that produced it, so the loop can't grade its own
  homework.
- **Hardstop** — a budget/count/cooldown ceiling, so a loop can't quietly break
  while burning tokens.

That auto-injection is the decisive difference from a plain prompt generator or a
developer-facing skill builder.

**Before → after (the elevator demo):**

```
User: "I want to summarize 100 shop reviews into 3 lines each"
        │
loop-forge:
  1. Diagnoses → Batch loop
  2. Interviews → where are the items? per-item task? where does output land? a cap?
  3. Auto-injects → verifier (count in == count out + independent spot re-check)
                  + hardstop (max_items budget + per-item fail cap + abort at 20% failure)
  4. Previews → "here's how it will run" (+ optional 1-item sample)
  5. Stamps → /review-summary  (reusable forever; safety baked in)
```

## When it triggers

- `/loop` or `/loop "<one-line situation>"` (full command `/loop-forge`; alias
  `/make-it-loop`)
- "automate this" / "make this repeatable" / "turn this into a command"
- "summarize all 100 reviews" / "do this for every item"
- "do X every time an email arrives" / "alert me when a condition is met"
- "generate a few options and pick the best one"
- any time you'd rather capture a recurring task as a reusable `/command` than
  re-type the prompt by hand

Triggers are matched on **intent, in any language** — the same phrasing in Korean,
Spanish, Japanese, etc. activates the skill, and the whole interaction then runs in
that language (see "Runs in your language" below).

## Runs in your language (English asset, multilingual behavior)

Every file in this skill is English — there is no per-language copy. At runtime the
orchestrator detects the user's language from their one-liner and conducts the
*entire* interaction in it: the analogy, every interview question, the missing-slot
re-asks, the default-value confirmations, and the dry-run preview. The stamped
`/command`'s human-readable prose (description, procedure, verifier/hardstop
explanations) is written in the user's language, while the structural tokens
(frontmatter keys, the archetype id, registry field names, and the ASCII slug
`name`) stay canonical so any teammate's harness can still parse it. This is
LLM-driven — there is no translation table.

## The 5 loop shapes (everything this tool stamps)

Non-developer work reduces to five shapes. There is **no sixth** — never invent one
(YAGNI). If a request doesn't fit, diagnose the nearest shape or ask one branch
question.

| Shape | One line | Catalog |
|---|---|---|
| **Batch** | Same task across N items, none skipped | `references/archetypes/batch.md` |
| **Pipeline** | Pass through ordered stages A→B→C | `references/archetypes/pipeline.md` |
| **Refine** | Make → evaluate → fix, repeated | `references/archetypes/refine.md` |
| **Watch** ⚠ most dangerous | Watch a target, act when a condition fires | `references/archetypes/watch.md` |
| **Explore** | Diverge into N candidates → converge to best K | `references/archetypes/explore.md` |

---

## 6-stage orchestration (the main flow)

Follow the flow exactly; each stage calls a specific asset (lazy-loaded).

> **Helper-script paths (install-portable)**: the `tools/` and `references/` paths
> below are relative to *this skill's own directory*. If a relative call can't find a
> file, resolve it under the skill root — `$HOME/.claude/skills/loop-forge/…` for
> `install.sh` installs, or `${CLAUDE_PLUGIN_ROOT}/skills/loop-forge/…` for marketplace
> (`/plugin install`) installs. Every helper is **optional**: if it's still
> unavailable (or `python3` is missing), perform the step yourself from the referenced
> doc — `classify_signals.py` is only a hint and `check_safety.py` only re-checks what
> Stage 4 already injected, so the flow degrades gracefully without them.

### Stage 1 — Entry
- Receive the one-line situation via `$ARGUMENTS`.
- If it's empty, ask first (in the user's language): **"What task do you keep doing
  by hand? Describe it in one line."** (e.g. "I want to summarize 100 shop reviews
  into 3 lines each.")

### Stage 2 — Diagnose the shape
- First-pass hint: run `tools/classify_signals.py "<situation>"` to get `ranked`
  (per-shape signal scores) and `ambiguous` (a tie flag). **This is only a hint —
  the LLM makes the final call** using the semantic signal table in
  `references/classifier.md`. The scorer ships an English keyword set; for
  non-English input it returns no signal, and the LLM classifies from meaning
  (language-agnostic), so classification never depends on surface keywords.
- If one candidate is clear, name it in plain language ("This is a **Batch** loop").
- If `ambiguous` (a top-2 tie) or a known conflict pair, fire the **branch question**
  from `classifier.md` — e.g. "All 100 at once? → Batch. Or each time a new one
  arrives? → Watch."

### Stage 3 — Interview for the blanks
- Pull the confirmed shape's slot questions from `references/interviewer.md` (each
  shape has its own set) and ask them with AskUserQuestion, in plain language.
- Apply the **missing-slot re-ask rule**: if the output location
  (`output_format`/`final_artifact`), the hardstop inputs
  (`max_items`/`max_iterations`/`period_limit`), or the eval criteria are left as
  "you decide," re-ask; if still blank, offer conservative defaults explicitly
  (Batch max 50 · Refine 4 iterations · Watch 20 actions/day, 5-min cooldown).
- For a **Watch** loop whose triggered action is external (sending/posting), ask
  "Preview before sending, or approve each one yourself?" to set `external_action=true`
  and the gate.
- Two common questions: **scope** ("Just this project, or usable anywhere?" →
  `project｜global`) and **name** (propose a slug, then confirm; a non-Latin answer
  is transliterated to an ASCII slug and confirmed).

### Stage 4 — Assemble (+ auto-inject safety + static check)
- Use `references/assembler.md` to substitute the slot values into the shape's
  skeleton (the `{slot}` placeholders), producing a **neutral loop spec JSON**
  (`references/loop-spec-schema.md`, 9 fields:
  `name / archetype / label / situation / scope / slots / skeleton /
  external_action / registry`).
- **Auto-inject safety**: copy the "default verifier" and "default hardstop" text
  from the chosen `archetypes/<shape>.md` into `registry.verifier` /
  `registry.hardstop`, and fill `registry.trigger / gate / accepted_signal` from the
  shape's mapping. For Watch (or any `external_action == true`), set the
  **language-independent** `registry.external_gate` to `dry_run` or `human_approval`
  (never `none`), matching the Stage-3 answer.
- **Static gate**: run `tools/check_safety.py <spec.json>`. Exit 2 (missing verifier
  or hardstop, or a Watch/external loop without an `external_gate`) → **bounce back
  to Stage 3** to fill the gap. Only exit 0 proceeds. **This gate is
  non-bypassable.**

> The loop-registry's 5 cells — **trigger / gate / verifier / hardstop /
> accepted_signal** — are first-class under `registry`, so every stamped loop is born
> registry-shaped. The added `external_gate` enum is what makes the Watch safety
> check pass in any language (it gates on the enum, not on prose markers).

### Stage 5 — Dry-run preview (the approval gate)
- Follow `assembler.md`'s **per-shape dry-run depth**: default = a text description
  ("here's how it will run": skeleton + slots + a summary of the injected safety);
  Batch/Explore may optionally run a 1-item sample (state the cost); **Watch =
  description only — running a real poll could fire a real send, so never sample it**;
  Pipeline/Refine = description plus, optionally, the first stage or one iteration.
- Show the preview and get **explicit approval**. **No approval, no stamping.**

### Stage 6 — Stamp (equivalent outputs)
- **Primary — Claude Code**: render with `references/renderers/claude-code.md`, then
  save by scope to `<cwd>/.claude/commands/<name>.md` (project) or
  `~/.claude/commands/<name>.md` (global). Invoke with `/<name>` + `$ARGUMENTS`.
- **Optional — Portable Prompt**: render with
  `references/renderers/portable-prompt.md` into a harness-agnostic, paste-able
  prompt block (works in any agent — paste the body into the session). This is an
  opt-in bonus, not required.
- **Equivalence contract**: the skeleton, verifier, hardstop, and accepted-signal
  text are **byte-identical** across both outputs; the only allowed difference is the
  invocation/variable syntax.
- Finish by telling the user how to run it (Claude Code: `/<name> <input>`; Portable
  Prompt: paste the block into your agent).

---

## Never do this (CRITICAL)

- ❌ **Never stamp without the Stage-5 approval.** Creating the command file is an
  irreversible artifact — a person sees the preview and says yes first.
- ❌ **Never stamp a spec missing a verifier or hardstop.** If `check_safety.py`
  exits 2, bounce to the interview; never bypass it. Auto-injecting the two safety
  devices a non-developer doesn't know to ask for is this tool's whole reason to
  exist.
- ❌ **Never stamp a Watch/external action without a dry-run or human-approval gate.**
  A monitor whose action is outbound (sending, posting, hitting a webhook) must carry
  "preview or human-approve first" — `registry.external_gate ∈ {dry_run,
  human_approval}`. It's the most dangerous shape, and the principle is "outbound
  action = independent gate" (the way email is drafted, then a human sends).
- ❌ **Never invent a sixth shape.** Reduce everything to
  Batch / Pipeline / Refine / Watch / Explore (YAGNI). If it doesn't fit, diagnose
  the nearest shape or ask one branch question.
- ❌ **Don't reimplement skill-creator / writing-skills.** Those are developer-facing
  authoring engines. loop-forge is the non-developer layer on top: a plain-language
  interview + shape diagnosis + safety injection.

---

## Dependent references (lazy load — call per stage)

| Asset | Purpose | Stage |
|---|---|---|
| `references/loop-spec-schema.md` | The 9-field loop spec + the 5 registry cells (+ `external_gate`) | 4 |
| `tools/loop_spec.schema.json` | Machine-validation schema (jsonschema) for the spec | 4 |
| `references/classifier.md` | Semantic signal table + branch-question rules | 2 |
| `tools/classify_signals.py` | Lightweight first-pass signal scorer (CLI hint) | 2 |
| `tools/corpus.jsonl` | Classifier regression corpus (50+ cases) | (tests) |
| `references/interviewer.md` | Per-shape slot questions + missing-slot re-asks + defaults | 3 |
| `references/archetypes/batch.md` | Batch shape (the 6-section structure template) | 2·3·4 |
| `references/archetypes/pipeline.md` | Pipeline shape | 2·3·4 |
| `references/archetypes/refine.md` | Refine shape | 2·3·4 |
| `references/archetypes/watch.md` | Watch shape (external-action gate) | 2·3·4 |
| `references/archetypes/explore.md` | Explore shape | 2·3·4 |
| `references/assembler.md` | Assembly, safety auto-injection, dry-run depth | 4·5 |
| `tools/check_safety.py` | Static safety check (exit 2 on a missing guard) | 4 |
| `references/renderers/claude-code.md` | Claude Code slash-command render rules | 6 |
| `references/renderers/portable-prompt.md` | Portable paste-able prompt render rules | 6 |
| `tools/examples/batch/{spec.json, claude-command.md, portable-prompt.md}` | Golden outputs (render ground truth) | 6 |

## Disabling

Uninstall or disable the plugin through Claude Code's plugin manager (`/plugin`), or
remove `skills/loop-forge` from `~/.claude/skills/` and `commands/loop-forge.md` from
`~/.claude/commands/` for a manual install.

## Related

- `docs/DESIGN.md` — the architecture and decision record for this plugin.
- The **loop-registry frame** (trigger / gate / verifier / hardstop / accepted) —
  every stamped loop is born matching it, so it's diagnosable at a glance.
- `skill-creator` / `writing-skills` — developer-facing authoring engines that
  loop-forge layers on top of (it is the non-developer layer, not a reinvention).
