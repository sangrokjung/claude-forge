# Assembler — slots + skeleton → loop spec + auto-injected verifier · hardstop

> Picture an **assembly line**. It drops the blanks the interviewer filled (the
> slots) into their places in the shape's skeleton, fits two parts the user *doesn't
> even know exist* (an inspector and a stop switch), and at the end a **quality
> checker** (`check_safety.py`) statically confirms no part is missing. The person
> fills only blanks ①–③; the line bolts on the ④⑤ safety devices and ships it.

This is **where the tool's core differentiator lives**. The decisive difference from
a developer-facing skill builder — every stamped loop is born with a verifier
(maker ≠ checker) and a hardstop (budget / count / cooldown).

---

## 1. Input and output

| | |
|---|---|
| **Consumes** | the `slots`·`scope`·`name`·`situation` the interviewer filled, the `archetype` the classifier set, and that `archetypes/<shape>.md`'s skeleton · default verifier · default hardstop text |
| **Produces** | **one neutral loop spec** conforming to `references/loop-spec-schema.md` (JSON, 9 fields) → passes `check_safety.py` → handed to the renderers |

The assembler is **rules, not an LLM**. Follow the deterministic procedure in §2–§4
exactly.

---

## 2. Assembly rules — filling the 9 fields

Fill the 9 fields (`name / archetype / label / situation / scope / slots /
skeleton / external_action / registry`) from these sources.

| Field | How it's filled |
|---|---|
| `name` | the slug the interviewer confirmed (`^[a-z][a-z0-9-]{1,30}$`), as-is |
| `archetype` | the shape ID the classifier set (`batch｜pipeline｜refine｜watch｜explore`) |
| `label` | the shape's canonical English label: Batch / Pipeline / Refine / Watch / Explore (rendered in the user's language at stamp time) |
| `situation` | the user's original one-line situation from the entry stage, verbatim |
| `scope` | the interviewer's common-question result (`project`｜`global`) |
| `slots` | the per-shape slot object the interviewer filled (keys defined by `archetypes/<shape>.md`) |
| `skeleton` | built by **§2.1 skeleton substitution** |
| `external_action` | the interviewer's result. **Watch defaults to `true`** (drop to `false` only when the interview clearly confirms the action isn't outbound). Other shapes are `true` if they include an outbound send/post |
| `registry` | the 5 cells filled by **§3 safety auto-injection** |

### 2.1 Skeleton substitution

Take the **③ Prompt skeleton** text from that `archetypes/<shape>.md` and substitute
the `{slot-key}` placeholders 1:1 with the user's answers in `slots`. The result is
the `skeleton` field (the procedure body).

- e.g. (batch): skeleton `1) Load the list from {input_source}…` → `1) Load the list
  from a reviews CSV (reviews.csv)…`.
- The skeleton's ④[verifier] · ⑤[hardstop] procedure lines are **left in place** (the
  safety must also be baked into the procedure). Substitute slots only; never delete
  or shorten the safety sentences.
- If a `{slot}` is left unsubstituted, that slot was blank → bounce back to the
  interview (re-ask).

---

## 3. Safety auto-injection rules (the core differentiator)

Fill the 5 `registry` cells. **Only `trigger` has a default; the other 4 are
auto-injected from the archetype catalog** — the tool fills in what a non-developer
doesn't even know to ask for (an inspector and a stop switch).

| `registry` cell | Injection source | Rule |
|---|---|---|
| `trigger` | (default) | a **manual `/command` run** by default. For **Watch**, it's the condition/interval (from that archetype's loop-registry mapping — fires when `{trigger_condition}` is met / polls on `{period_limit}`) |
| `gate` | `archetypes/<shape>.md` loop-registry mapping "gate" value | copy as-is (e.g. batch=`N ≤ max_items`, watch=pre-action gate + dry-run/approval if outbound) |
| `verifier` | `archetypes/<shape>.md` **④ default verifier** text | **copy verbatim, auto-injected.** Source = that shape's catalog ④ section (a person does not write a new one) |
| `hardstop` | `archetypes/<shape>.md` **⑤ default hardstop** text | **copy verbatim, auto-injected.** Source = that shape's catalog ⑤ section |
| `accepted_signal` | `archetypes/<shape>.md` **⑥ accepted signal** text | copy verbatim |

> **The source of the auto-injection is always the ④⑤⑥ body text of that
> `archetypes/<shape>.md`.** The assembler *copies* those sentences into `registry`;
> it never weakens or deletes them. When a slot value (e.g. `max_items`) appears in
> the verifier · hardstop text, substitute only that spot with the user's value
> (e.g. "max_items budget cap" → "max_items 100 budget cap").

### 3.1 Watch outbound gate guarantee (the most dangerous shape)

If `archetype == "watch"` or `external_action == true`:
- Set the **language-independent enum** `registry.external_gate` to `dry_run` or
  `human_approval` (**never `none`**), matching the interviewer's §3.5 answer
  ("auto-pass after dry-run preview" → `dry_run`; "approve each one" →
  `human_approval`). The injected `registry.verifier` prose also describes this gate
  in the user's language (Watch's ④ default verifier already includes it).
- Without a valid `external_gate`, §4's `check_safety.py` **rejects with exit 2** —
  the assembler can't hand it to the stamp. The principle: **outbound action = an
  independent gate** (the way email is drafted, then a human sends).

> **Why an enum, not a prose marker.** If the gate were checked by substring-matching
> English words like "dry-run" or "approval," a Watch loop whose verifier prose is in
> another language would silently fail the gate. So the deterministic check enforces
> the structured `external_gate` enum; the human-readable verifier prose can be in any
> language. (A legacy English-marker substring scan may remain as a secondary,
> advisory signal, but the enum is the source of truth.)

---

## 4. Static safety check — the `check_safety.py` gate

**Just before** handing the assembled spec to the stamp (render), statically check it
with `tools/check_safety.py <spec.json>`. Do not stamp until it passes (exit 0).

Checks (all deterministic):
1. **jsonschema valid** — does it satisfy `tools/loop_spec.schema.json` (9 fields
   required, `additionalProperties:false`, enum/pattern checks, every `registry`
   cell `minLength≥1`, the `external_gate` enum)?
2. **`registry.verifier` non-empty** — reject if the inspector (maker ≠ checker) is
   empty.
3. **`registry.hardstop` non-empty** — reject if the stop switch (budget / count /
   cooldown) is empty.
4. **Outbound gate** — if `archetype == "watch"` or `external_action == true`, then
   `registry.external_gate` must be `dry_run` or `human_approval` (not `none`/absent).
   Reject otherwise.

Result: **pass → exit 0** (proceed to render). **Violation → print the issue list to
stderr and exit 2** (bounce back to interview/assembly). Verify with:

```bash
cd skills/loop-forge/tools
uv run --with jsonschema python check_safety.py examples/batch/spec.json   # → exit 0
```

> `check_safety.py` is the assembler's *last deterministic gate*. In SKILL.md Stage 4
> (assemble), if this gate exits 2, bounce to the interview — a loop without an
> inspector and a stop switch is never stamped. **This gate is non-bypassable.**

---

## 5. Dry-run depth rules (per-shape, graded)

In SKILL.md Stage 5 (preview), the **depth** of "here's how it will run" differs by
shape. Watch carries the most execution risk, so it's description-only.

| Shape | Default depth | Option (only on the user's explicit request) | Why |
|---|---|---|---|
| **Common default** | **a text description** — show the skeleton + filled slots + a summary of the injected safety (verifier · hardstop) and say "here's how it will run" | — | the person confirms what will run before any irreversible action |
| **Batch** | text description | **a 1-item sample** (max 1 item, **state the expected cost** first) | one item is cheap and reversible → samples whether the skeleton fits |
| **Explore** | text description | **a 1-item sample** (generate just 1 candidate, state the cost) | one divergence is a cheap sample |
| **Pipeline** | text description | **the first stage only**, once (optional) | the full pipeline is costly/slow → the first stage just confirms input/output shape |
| **Refine** | text description | **one iteration only** (one generate→evaluate cycle, optional) | infinite-polish risk → one cycle confirms the eval criteria work |
| **Watch** | **description only (no execution)** | **no 1-item sample** | outbound/irreversible risk — actually running a poll/trigger could fire a real send/post. **Description only** |

> For Watch, the dry-run *is* the safety device baked into the stamped loop (the ④
> outbound gate); it is **not** something you actually execute in the preview stage. A
> Watch preview describes "once stamped, here's the gate and here's how it runs" — **in
> words only**.

After the preview, the spec must pass the **user-approval gate** (no stamping without
approval, SKILL.md Stage 5) before Stage 6 (stamp).

---

## 6. Related

- `references/loop-spec-schema.md` — the 9-field neutral spec + jsonschema the
  assembly result must conform to
- `references/archetypes/<shape>.md` — the **auto-injection source** for the skeleton
  (③) · default verifier (④) · default hardstop (⑤) · accepted (⑥) · gate mapping
- `references/interviewer.md` — supplies the assembly inputs (slots · scope · name)
  and the outbound (dry-run/approval) choice
- `tools/check_safety.py` — the §4 static gate (verifier/hardstop non-empty + Watch
  `external_gate` enum)
- `references/renderers/{claude-code, portable-prompt}.md` — render the passing spec
  into per-platform outputs
