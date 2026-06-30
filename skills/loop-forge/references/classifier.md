# Classifier — situation sentence → loop shape

> Picture an ER triage nurse. A patient (a one-line situation) walks in; the nurse
> hears the symptom words (diagnostic signals) and makes a first cut — "which of the
> 5 departments (loop shapes) is this?" If it's ambiguous, she asks **one more
> sentence** (a branch question) to settle the department. The final diagnosis is the
> doctor's (the LLM in `SKILL.md`).

The classifier is a **two-layer** design.

1. **Lightweight signal scorer** (`tools/classify_signals.py`) — a deterministic
   keyword count that produces an **instant first-pass hint** (a ranked list + an
   ambiguity flag). Fast and reproducible, but it only sees surface words.
2. **LLM final call** (`SKILL.md`) — takes that hint as input but makes the
   **final shape decision** using the semantic signal table below plus the meaning
   behind it (Doing the same thing repeatedly? Passing through once each? Picking the
   best? Watching continuously?). What the scorer misses — paraphrase, idiom,
   context, and any non-English input — the LLM fills in.

> Contract (CRITICAL): **the scorer's output is a hint, not a verdict.** Even when a
> `top` is returned, the LLM re-confirms it against the semantic table; when
> `ambiguous` is `true` or `top` is `null`, the LLM **must** ask a branch question
> first.

> **Runs in the user's language.** The scorer ships an **English** keyword set, so
> for non-English input it simply returns no signal (`top: null`) — and the LLM
> classifies directly from the *meaning* in the table below. Classification
> correctness **never depends on language-specific keywords**; the scorer is always a
> hint and the LLM is the final, language-agnostic classifier. The branch questions
> in §2 are templates the LLM renders in the user's own language.

---

## 1. Semantic signal table (shape × keywords)

The keyword phrases below **mirror** the "① Diagnostic signals" section of the five
`references/archetypes/<shape>.md` catalogs, and they match the `SIGNALS` dict in
`classify_signals.py` 1:1 (fix one of the three, fix the other two).

| Shape | One line | Diagnostic signal phrases |
|---|---|---|
| **Batch** | Same task across N items, none skipped | "100 of them", "process N items", "run through all N", "all of them", "summarize them all", "every single one", "each one", "one by one", "for every item", "this list", "the whole list", "the entire set", "in bulk", "all at once", "go through them" |
| **Pipeline** | Pass through ordered stages A→B→C, once each | "then", "after that", "use that to", "in order", "one after another", "step by step", "do A then B then C", "A → B → C", "run it through", "pass it through", "hand it off to", "first do X then later do Y" |
| **Refine** | Make → evaluate → fix, on the same target, repeated | "make it better", "raise the quality", "more polished", "refine it", "polish it", "touch it up", "draft and fix", "fix it up", "iterate on it", "make it nicer", "revise it a few times" |
| **Watch** | Watch what will arrive; act when a condition fires | "every time one arrives", "whenever a new one comes in", "when something new shows up", "when it pops up", "when it appears", "when it happens", "when detected", "when it's caught", "when it matches", "when a condition is met", "automatically when X", "auto-notify me", "send me an alert", "check and let me know" |
| **Explore** | Diverge into N candidates, keep only the best K | "several", "a few options", "make a few", "ideas", "candidates", "compare options", "pick one", "the best", "the strongest", "the top choice", "make N and pick the best", "generate and choose", "choices", "among several versions" |

> Ultra-common single tokens that over-match (e.g. a bare "then" or "all") are
> deliberately kept narrow in the scorer — they fire on unrelated phrasing and ruin
> separation. When no surface keyword is present, the LLM classifies from meaning.

---

## 2. Branch-question rules (one sentence per confusion pair)

When the signals land **across two shapes in a near-tie** (the scorer returns
`ambiguous: true`) or the LLM is semantically unsure, split it with **a single
sentence**, then settle. Each row records the key distinguishing axis.

| Confusion pair (`pair`) | Branch question | Key distinction |
|---|---|---|
| **batch ↔ watch** | "Process the N you have **all at once** and you're done? (Batch) Or react **each time a new one arrives**, going forward? (Watch)" | Batch = sweep an *already-gathered finite list* once and end · Watch = keep watching *what will arrive* and react |
| **pipeline ↔ refine** | "Pass through fixed stages **in order, once each**? (Pipeline) Or repeat **the same thing to make it steadily better**? (Refine)" | Pipeline = *different stages* once each (A→B→C) · Refine = *the same target* through generate ↔ evaluate, many times |
| **explore ↔ batch** | "Keep only the **best** of several? (Explore) Or process all N items, **each one**? (Batch)" | Explore = make many, *keep few* (you pick) · Batch = keep as many as you made (no picking) |

> These three pairs match the `CONFLICT_PAIRS` in `classify_signals.py`. If two
> *other* shapes tie (e.g. refine ↔ explore), model a one-sentence branch question on
> the rows above ("Repeat and refine the same thing, or pick the best among several
> candidates?") on the spot.

---

## 3. Classification procedure (called from SKILL.md Stage 2, "Diagnose the shape")

1. **Get the first-pass hint** — run `python3 tools/classify_signals.py
   "<situation>"` and read `ranked` (signal count per shape), `top`, `ambiguous`,
   and `pair`.
2. **Branch on the verdict**
   - `top` is set and `ambiguous: false` → hold it as a candidate, but re-confirm it
     for one second against the **meaning** in §1. If it holds, tell the user "This
     is a **{shape}** loop" and move on to the slot interview.
   - `ambiguous: true` → fire the `pair`'s branch question (§2) **verbatim, as one
     sentence**. The answer settles the shape.
   - `top: null` (zero signals — e.g. non-English input) → the scorer caught nothing;
     the LLM classifies directly from the §1 meaning, or builds a §2-style branch
     question from the two nearest shapes.
3. **No shape beyond the five (YAGNI)** — every situation reduces to one of the five.
   Never invent a new shape; if a request doesn't fit cleanly, absorb it into the
   nearest shape plus its slots.

---

## 4. Regression pinning (tests)

- Corpus: `tools/corpus.jsonl` — unambiguous cases per shape plus designed
  confusion-pair ambiguous cases (English).
- Test: `tools/test_classify_signals.py` — ① 100% top-1 on the unambiguous corpus,
  ② 100% `ambiguous` flag on each conflict-pair case (so the branch question fires).
- Run: `cd skills/loop-forge/tools && uv run --with pytest pytest
  test_classify_signals.py -v`.
- If you change the signal table, change all three (this table / the archetypes'
  ① diagnostic signals / the `SIGNALS` dict) together and make the tests pass again.

## 5. Related files

| Path | Role |
|---|---|
| `tools/classify_signals.py` | First-pass signal scorer (the `SIGNALS` dict mirrors this table) |
| `tools/corpus.jsonl` | Classification regression corpus (unambiguous + ambiguous) |
| `tools/test_classify_signals.py` | Top-1 (unambiguous) / ambiguous-flag (conflict pairs) regression tests |
| `references/archetypes/*.md` | Source of the "① Diagnostic signals" (this table mirrors them) |
| `references/interviewer.md` | Confirmed shape → slot questions |
| `SKILL.md` | Calls this classifier in Stage 2, "Diagnose the shape" |
