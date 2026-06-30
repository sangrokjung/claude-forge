# Interviewer — per-shape blank-filling questions + missing-slot re-asks

> Picture a **fill-in-the-blanks interviewer**. Each shape hands the user a different
> form — Batch's form asks "Where are the N items? What per item?", Watch's asks
> "What do I watch? What does it react to?". When the applicant (a non-developer)
> leaves a blank — *especially* the blanks for **where the output lands** and **when
> to stop** — the interviewer points right at it and re-asks: "you can't leave that
> one blank."

> **Runs in the user's language.** Every question below is a **template**. At runtime
> the orchestrator renders it in the user's own language: plain, conversational, with
> a one-line gloss on any jargon the first time it appears — e.g. "a sheet (Excel ·
> Google Sheets)", "CTR (the share that clicks through)", "idempotency (a marker that
> keeps the same thing from being done twice)". Keep it to a sentence or two; don't
> stack tables and acronyms.

---

## 0. What this is / where it fits

This file owns **Stage 3 (the slot interview)** of the 6-stage flow.

```
Stage 2 (classifier) → archetype ID (batch｜pipeline｜refine｜watch｜explore)
        ↓
Stage 3 (interviewer, this file)  archetype ID → that shape's slot definitions →
                                  plain-language questions → filled slots
        ↓
Stage 4 (assembler) → slots + skeleton → loop-spec JSON
```

- **Consumes**: ① the archetype ID from `classify`, ② that
  `references/archetypes/<shape>.md`'s "② Slots" definitions (slot keys +
  plain-language questions), ③ the entry-stage `situation` (the original one-liner).
- **Produces**: ① a filled `slots` object (**100% of the keys** the catalog defines),
  ② `scope` (`project｜global`), ③ `name` (a proposed slug, confirmed with the user),
  ④ (Watch only) the settled `external_action` value.

> ⚠ **The canonical source of slot keys is each `archetypes/<shape>.md`.** The
> questions in this file are just the **script** for asking those keys in plain
> language; they never invent or drop a key (zero key omission). If the archetype
> catalog changes a key, change the question here to match.

## 1. Interview flow (same order for every shape)

1. **Read the situation back**: "So — *{situation}*, right? This looks like a
   **{label}** loop." (a one-line confirmation of the classifier's call)
2. **Ask the shape's slot questions**: pose the matching question set from §2 below.
   Use AskUserQuestion to gather them in **1–2 bundles** (2–3 questions per bundle) at
   once — so a non-developer isn't worn down by one blank at a time.
3. **Re-ask the missing ones**: re-ask any dropped blank (especially the "commonly
   dropped slots" in §3) per the §3 rules, or offer a conservative default.
4. **Two common questions**: §4's `scope` (this project only vs. anywhere) + `name`
   (propose and confirm a slug).
5. **Produce**: fill `slots`/`scope`/`name` (+ `external_action` for Watch) and hand
   off to Stage 4 (the assembler).

---

## 2. Per-shape question sets (5 — each covering 100% of its slot keys)

Each set uses the **same wording** as that `archetypes/<shape>.md`'s "② Slots"
plain-language questions (slot key ↔ question, 1:1). A suggested AskUserQuestion
bundling is noted with each.

### 2.1 Batch — 4 slots `input_source · per_item_task · output_format · max_items`

> Bundling: **Bundle A** (① where the input · ② what per item) → **Bundle B**
> (③ where/what form the output · ④ at most how many).

| # | Slot key | Question (template) |
|---|---|---|
| ① | `input_source` | "**Where** are the N items to process? (a folder / a sheet (Excel · Google Sheets) / a list of links / a database)" |
| ② | `per_item_task` | "For **each single item**, what should I do?" |
| ③ | `output_format` | "**Where and in what form** should the results land? (e.g. a `summary.md` table / a new folder / printed to screen)" |
| ④ | `max_items` | "For safety, **at most how many** should I process? (the budget ceiling — leave blank for a conservative default of 50)" |

→ ③·④ are the ones non-developers drop most → §3.1·§3.2 re-ask targets.

### 2.2 Pipeline — 3 slots `stages · stage_io · final_artifact`

> Bundling: **Bundle A** (① list the stages · ② per-stage input/output) → **Bundle B**
> (③ the final artifact).

| # | Slot key | Question (template) |
|---|---|---|
| ① | `stages` | "What **stages do you go through, in order**? List the stage names with arrows. (e.g. research → draft → proofread)" |
| ② | `stage_io` | "**What does each stage take in and put out?** (one stage's output becomes the next stage's input)" |
| ③ | `final_artifact` | "**What do you hold at the very end**, and where does it land? (e.g. a single finished `final.md`)" |

→ ② (the hand-off between stages) and ③ (the final artifact) tend to slip into "just
connect them for me" → §3.1·§3.3 re-ask targets.

### 2.3 Refine — 4 slots `target · eval_criteria · satisfy_threshold · max_iterations`

> Bundling: **Bundle A** (① what · ② what counts as good) → **Bundle B**
> (③ the satisfaction threshold · ④ at most how many rounds).

| # | Slot key | Question (template) |
|---|---|---|
| ① | `target` | "**What** are we polishing? (an existing draft / something to create from scratch)" |
| ② | `eval_criteria` | "**What makes it 'good'?** Write 1–5 criteria to score against. (e.g. clarity · curiosity · length)" |
| ③ | `satisfy_threshold` | "**How good is good enough?** (the satisfaction threshold — e.g. ≥ 85 out of 100; leave blank for a conservative default of 85)" |
| ④ | `max_iterations` | "For safety, **at most how many rounds** of fixing? (the iteration ceiling — leave blank for a conservative default of 4)" |

→ ②·③ left blank lets evaluation drift into the subjective ("looks good") and loop
forever → §3.4 re-ask target. ④ is a §3.2 hardstop re-ask target.

### 2.4 Watch — 4 slots `watch_target · trigger_condition · trigger_action · period_limit` ⚠ outbound-action check required

> Bundling: **Bundle A** (① where · ② what fires it) → **Bundle B** (③ what action ·
> ④ interval/daily cap) → (if ③ is an outbound send) the **outbound-action check
> question** (§3.5).

| # | Slot key | Question (template) |
|---|---|---|
| ① | `watch_target` | "**Where** should I watch? (e.g. an inbox / a specific folder / a board or channel / a sheet (Excel · Google Sheets))" |
| ② | `trigger_condition` | "**What, when seen,** should I react to? (the trigger condition — e.g. subject contains 'X' / a new file arrives / a number crosses a threshold)" |
| ③ | `trigger_action` | "When the condition matches, **what action** should I take? (e.g. an on-screen alert / make a summary / an **outbound action** like **sending email** or **posting**)" |
| ④ | `period_limit` | "**How often** should I check, and **at most how many times a day** should I act? (interval + daily cap — leave blank for a conservative default: every 5 min · 20/day)" |

→ if ③ is an outbound send/post, set `external_action=true` and fire the §3.5
outbound-action check question. ④ is a §3.2 hardstop re-ask target.

### 2.5 Explore — 4 slots `generate_target · candidate_count · selection_criteria · final_count`

> Bundling: **Bundle A** (① what to make several of · ② how many to diverge) →
> **Bundle B** (③ the picking criteria · ④ how many to keep).

| # | Slot key | Question (template) |
|---|---|---|
| ① | `generate_target` | "**What** should I make several of? (e.g. title options / copy / design mockups / ideas)" |
| ② | `candidate_count` | "How many **candidates** should I generate? (the divergence count — leave blank for a conservative default of 8)" |
| ③ | `selection_criteria` | "By **what criteria** should I pick? Write 1–5. (e.g. click-through (CTR) · clarity · length)" |
| ④ | `final_count` | "How many should I **keep** at the end? (the convergence count — leave blank for a conservative default of 3)" |

→ ③ left blank lets selection drift into the subjective ("this one grabs me") and
become irreproducible → §3.4 re-ask target. ②·④ are §3.2 divergence/convergence
default targets.

---

## 3. Missing-slot re-ask rules (the blanks non-developers drop most)

> **If it's vague, don't let it slide — re-ask with a concrete example.** Non-
> developers almost always drop "where the output lands (output)" and "when to stop
> (hardstop)," and without those two a loop falls into the "quietly breaks while
> burning money" failure.

| Dropped slot | Trigger (an answer like this) | Re-ask / handling |
|---|---|---|
| `output_format` (batch) · `final_artifact` (pipeline) | "just figure it out" / "show me the results" / no output location or form | **Re-ask**: "**Where** does the result land for this to count as done? e.g. a `summary.md` table / a new folder / printed to screen." (Keep re-asking until an observable artifact is pinned down — prevents soft completion.) |
| `max_items` (batch) · `max_iterations` (refine) · `period_limit` (watch) ＝ **the 3 hardstop inputs** | "just all of them" / "to the end" / "stop on your own" / no ceiling | **Re-ask**: "For safety we need a **ceiling**. At most how **many / how many rounds / what interval**?" → if still blank, **propose and confirm a conservative default**: batch `max_items=50`, refine `max_iterations=4`, watch `period_limit=every 5 min · 20/day`. (Explore `candidate_count=8` · `final_count=3` get the same treatment when blank.) |
| `eval_criteria`/`satisfy_threshold` (refine) · `selection_criteria` (explore) ＝ **the eval/selection criteria** | "just make it better" / "whichever is best" / no criteria | **Re-ask**: "**What do you look at** to judge 'this got better / this is the best'? Write 1–5 criteria to score against." (Without criteria, evaluation drifts subjective and loops forever → keep re-asking until criteria are filled. If the threshold is also blank, propose refine `satisfy_threshold=85`.) |
| `stage_io` (pipeline) ＝ **the hand-off between stages** | "just connect them" / no per-stage input/output | **Re-ask**: "**What does this stage have to put out** before the next stage can start? Write one line per hand-off between stages." (It's the basis for the exit gate — blank means stages silently drift out of sync.) |
| `trigger_action` (watch) is an **outbound send** | "email it" / "post it to social" / "send it to ___" — anything that goes **outbound** | **Fire the §3.5 outbound-action check question** (below) — set `external_action=true`. |

### 3.5 Watch outbound-action check (CRITICAL — only for outbound sends/posts)

If `trigger_action` is an **outbound send/post** (sending mail, posting to social,
hitting a webhook — anything that leaves and can't be undone), ask one more
question:

> **"Before it goes out, how should I check it?"**
> - ① **Preview (dry-run) and proceed** — show "here's what will go out" first; once
>   a person says OK, then execute.
> - ② **Approve each one yourself** — send only after a person OKs every single item.

- This answer settles two things: ① `external_action=true`, and ② which **outbound
  gate mode** the assembler bakes into the Watch verifier (pass-after-preview vs.
  wait-for-human-approval).
- **The outbound gate is not optional** — one of the two is always on (zero gate on
  an outbound send is impossible). The assembler records the choice as the
  language-independent enum **`registry.external_gate ∈ {dry_run, human_approval}`**
  (never `none`), and `tools/check_safety.py` **rejects with exit 2** if a
  Watch/`external_action` spec lacks it. (The gate is enforced on the enum, not on
  prose, so it holds in any language.) The principle: **outbound action = an
  independent gate** (the way email is drafted, then a human sends).
- If `trigger_action` is an **internal action** (an on-screen alert, making a
  summary — nothing leaves), `external_action` may be set to `false` — but Watch's
  default is the conservative `true`, and even when dropped to internal the
  **pre-action gate (independent false-positive re-confirmation)** still runs.

---

## 4. Two common questions (every shape)

After the shape's slots are filled, ask the two blanks the stamp needs.

### 4.1 `scope` — where it's saved (project｜global)

> **"This command — where will you use it?"**
> - ① **In this project only** (`project`) → `<cwd>/.claude/commands/<name>.md`
> - ② **Anywhere (all projects)** (`global`) → `~/.claude/commands/<name>.md`

- Plain gloss: "Is this just for the folder you're working in now, or do you want it
  for other work too?"
- This value decides the save path used by both renderers in Stage 6
  (`renderers/{claude-code, portable-prompt}.md`).

### 4.2 `name` — propose and confirm a command slug

> Propose a **lowercase ASCII slug** from the situation and confirm it. Rule:
> `^[a-z][a-z0-9-]{1,30}$` (starts lowercase, then lowercase/digits/hyphens, 2–31
> chars total).

- Example proposals: "summarize 100 reviews" → `review-summary`, "pick title
  options" → `title-pick`, "alert me on email keyword X" → `mail-watch`.
- Show it to the user as the **call name**: "Should this command be called
  `/review-summary`? Tell me if you'd prefer another name."
- If the user answers in a **non-Latin language**, transliterate / semantically slug
  it into ASCII and re-confirm (a slug that breaks the rule is auto-corrected, then
  confirmed). This generalizes to any language.

---

## 5. Plain-language principles (rules for writing the questions)

- **Conversational, polite** — "what should…?", "is there…?" (no imperatives, no
  stiff formal register).
- **Gloss jargon on first use** — sheet (Excel · Google Sheets) / CTR (the share
  that clicks through) / dry-run (a preview) / idempotency (a marker that keeps the
  same thing from being done twice) / slug (a lowercase ASCII command name).
- **Conclusion first, examples in parentheses** — one-line question + options in
  parens. Don't stack tables and acronyms.
- **Don't force blanks, but never leave the safety blanks empty** — output location,
  hardstop, and eval criteria get re-asked per §3 or get a conservative default
  **stated explicitly** (no silent defaults — show the user what value went in).

## 6. Output → next stage

When the interview ends, fill the following and hand off to Stage 4 (the assembler,
`assembler.md`):

- `slots`: an object with **all** the shape's slot keys filled (zero omission — blank
  ones settled with §3 defaults).
- `scope`: `project｜global`.
- `name`: a rule-passing slug (confirmed with the user).
- (Watch) `external_action`: `true` + the §3.5 gate mode if outbound, `false` if
  internal.

> The assembler substitutes these `slots` into the `{slot}` placeholders of the
> shape's skeleton (`archetypes/<shape>.md` ③) and auto-injects the ④⑤ verifier ·
> hardstop plus the `registry` cells. The interviewer's job is **to gather every
> blank, leaving none empty.**

## 7. Related

- `references/archetypes/<shape>.md` — the **canonical source** of ② slot
  definitions (slot keys · question wording). The questions here mirror them.
- `references/classifier.md` — supplies Stage 2 (the shape ID) + the confusion-pair
  branch questions (the shape is settled before the interview).
- `references/loop-spec-schema.md` — the neutral spec contract where
  `slots`/`scope`/`name`/`external_action` land.
- `references/assembler.md` — Stage 4: substitute the skeleton with these `slots` +
  auto-inject the verifier · hardstop.
