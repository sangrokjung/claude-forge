# Archetype catalog — Refine

> Picture a **potter at the wheel**. You shape the same bowl (the target) → step back
> and judge it → shape the weak spots again. But there's no "perfect," so **you stop
> when the score stops climbing** — keep touching it forever and you only burn time,
> and eventually ruin it.

---

> **This file follows the "structure standard" (`batch.md`) for all 5 archetype
> catalogs.** Same **6-section + loop-registry 5-cell mapping + one example**
> structure. The content here is Refine's; the shape of the cells (section order and
> names) is standardized on batch.md.
>
> **The 6-section standard**: ① Diagnostic signals / ② Slots / ③ Prompt skeleton /
> ④ Default verifier / ⑤ Default hardstop / ⑥ Accepted signal. After those comes the
> **loop-registry 5-cell mapping** table and **one example**.

---

## One-line definition

**Take one target and make → evaluate → fix it, steadily better.** "Polish the same
thing over and over, but stop where you can't lift it further" is the heart of it.

Loop-spec fields: `archetype: refine`, `label: Refine`.

## ① Diagnostic signals (phrases that point to Refine)

When the classifier (`classifier.md`) finds these signals in the situation
sentence, it treats Refine as a candidate. The scorer ships an English keyword set;
for any other language the LLM reads the *meaning*.

- "make it better", "raise the quality", "more polished"
- "refine it", "polish it", "touch it up"
- "draft and fix", "fix it up", "iterate on it"
- "make it nicer", "polish it well", "revise it a few times"

> ⚠ **Watch out for the confusion pair.** If the sentence also carries "and then /
> in order / pass through" — like "research it, write it up, *then* polish it" — it's
> a tie with **Pipeline** → fire the branch question: "Pass through fixed stages *in
> order, once each*? (Pipeline) Or repeat *the same thing* to make it steadily
> better? (Refine)". The key distinction — Pipeline passes through *different stages*
> once each (A→B→C); Refine repeats *the same target* through evaluate · fix many
> times (generate → evaluate → fix → evaluate → …).

## ② Slots (4 blanks to ask the user)

The interviewer (`interviewer.md`) asks these 4 blanks as **plain-language
questions, posed in the user's own language at runtime**. The keys go straight into
the loop spec's `slots` object.

| Slot key | Plain-language question | Example answer |
|---|---|---|
| `target` | "**What** are we refining? (an existing draft / something to create fresh)" | a YouTube thumbnail copy draft |
| `eval_criteria` | "**What makes it 'good'?** Write 1–5 things to score it on. (e.g. clarity · curiosity · length)" | clarity, curiosity, length |
| `satisfy_threshold` | "**How good is good enough?** (the satisfaction threshold — e.g. ≥ 85 out of 100; leave blank for a conservative default of 85)" | score ≥ 85 |
| `max_iterations` | "For safety, **at most how many times** should I revise? (the iteration cap — leave blank for a conservative default of 4)" | 4 |

> ⚠ **`eval_criteria` and `satisfy_threshold` are the blanks a non-developer most
> often skips.** With no criteria and only "just make it better," evaluation drifts
> into **subjectivity ("looks good to me")** and falls into infinite revision. If the
> criteria are blank the interviewer re-asks "what tells you it got better?", and if
> the threshold (`satisfy_threshold`) and cap (`max_iterations`) are blank it offers
> conservative defaults (85 / 4). **Both the threshold and the max-iterations must be
> filled** to stop infinite polishing.

## ③ Prompt skeleton (the procedure with variables substituted)

The assembler (`assembler.md`) substitutes the slot values into the `{slot}`
placeholders to build the `skeleton` field.

```
1) Generate a draft of {target} (if one already exists, treat it as round 1).
2) [evaluate] Score each of {eval_criteria} (per-criterion score + total).
   No subjective "looks good" verdicts — write a rationale and a score per criterion.
3) [fix] Fix only the shortfall on the low-scoring criteria, pinpointed.
4) [re-evaluate] Score again with {eval_criteria}.
5) Stop on any one of these:
   · total ≥ {satisfy_threshold} (satisfied), or
   · iterations ≥ {max_iterations} (cap reached), or
   · the score stagnates twice in a row (gain < the delta threshold) → early stop.
   (No infinite polishing.)
6) [verifier] The evaluation that assigns the final score runs in a pass SEPARATE
   from the flow that did the last fix (maker ≠ checker).
```

> Steps ④⑤ (verify · stop) are easy for a non-developer to forget → the assembler
> **auto-injects** the ④⑤ text below. The user only fills slots ①–③ and ④⑤ come along.

## ④ Default verifier (auto-injected — maker ≠ checker)

> **Evaluator separate from generator (maker ≠ checker)** + **explicit scored
> criteria (no subjective "looks good")**.

- **Why a separate evaluator**: if the same flow that just fixed the answer judges
  "did it get better?", it grades its own fix generously and calls it "satisfied"
  even when nothing improved. So evaluation runs in a pass **separate from the fix**.
- **Explicit scored criteria**: if evaluation is subjective ("looks good"), the
  score comes out different every time and the stop condition collapses. Write a
  score and a rationale per criterion in `eval_criteria`, and decide
  satisfied/stagnant **on objective scores only**.

## ⑤ Default hardstop (auto-injected — max iterations AND stagnation early-stop, both)

> **At most `max_iterations`** · **early stop on 2 consecutive stagnant scores (gain
> < the delta threshold)** — **no infinite polishing**.

- **Iteration cap**: `max_iterations` is the time/cost ceiling. Even short of the
  satisfaction threshold, once you hit the cap, stop and report "this is the best so
  far."
- **Stagnation early-stop**: if two fixes in a row barely move the score (gain < the
  delta threshold), more tinkering is wasted effort → **stop early**, even before the
  cap. This is the key device that stops the **infinite-refine** failure (the loop
  that chases "make it better" forever, burning time).
- You need both together to stop "raise the quality" from spinning endlessly.

## ⑥ Accepted signal (the observation that counts as done)

> **Score ≥ threshold** or **an explicit "can't lift it further"** + **the final
> copy**.

Not "it feels done" — it counts as "done" only when ① the total is at or above
`satisfy_threshold`, or ② "stagnated, can't lift it further" is explicitly recorded,
and ③ the final artifact actually exists (no soft completion).

## loop-registry 5-cell mapping

| loop-registry cell | Value (`registry` field) |
|---|---|
| trigger (`trigger`) | manual `/command` run |
| gate (`gate`) | an eval-criteria definition exists (if `eval_criteria` is empty, block entry and re-ask) |
| verifier (`verifier`) | §④ — evaluator separate from generator (maker ≠ checker) + explicit scored criteria (no subjectivity) |
| hardstop (`hardstop`) | §⑤ — at most `max_iterations` · early stop on 2 consecutive stagnant scores (no infinite polishing) |
| accepted_signal (`accepted_signal`) | §⑥ — score ≥ threshold or an explicit "can't lift it further" + the final copy |

## Example — "Polish a thumbnail copy"

| Slot | Value |
|---|---|
| `target` | a YouTube thumbnail copy draft |
| `eval_criteria` | [clarity, curiosity, length] |
| `satisfy_threshold` | score ≥ 85 (out of 100) |
| `max_iterations` | 4 |

Assembled result (summary):
- **skeleton**: generate the copy draft → [evaluate] score clarity · curiosity ·
  length → [fix] improve only the low criteria → [re-evaluate] → stop on total ≥ 85
  or 4 iterations or 2 consecutive stagnant scores → [verify] the final evaluation
  runs in a pass separate from the fix.
- **registry.verifier**: evaluator separate from generator (maker ≠ checker) +
  explicit rationale for clarity · curiosity · length scores (no subjective "looks
  good").
- **registry.hardstop**: at most 4 iterations · early stop on 2 consecutive stagnant
  scores (gain < the delta threshold) — no infinite polishing.
- **registry.accepted_signal**: total ≥ 85 or an explicit "stagnated, can't lift it
  further" + the final copy exists.

> The full loop-spec JSON for this example lives in `references/loop-spec-schema.md`
> and `tools/examples/refine/spec.json` (schema-validated).

## Related

- `references/loop-spec-schema.md` — the neutral spec contract these slots ·
  skeleton · registry land in
- `references/classifier.md` — the mirror of ① diagnostic signals (the SIGNALS
  dict) + the confusion-pair (pipeline ↔ refine) branch question
- `references/interviewer.md` — ② the slots as plain-language questions + the
  missing-slot re-asks (especially `eval_criteria` · `satisfy_threshold` ·
  `max_iterations`)
- `references/assembler.md` — ③ skeleton substitution + the ④⑤ auto-injection rules
- `tools/check_safety.py` — static rejection (exit 2) when ④⑤ are missing
