# Archetype catalog — Explore

> Picture an **audition**. You put several contestants (candidates) on stage at once
> to show off differently, then score them against fixed criteria and pass only the
> top few. The judge can't be one of the people on stage (maker ≠ picker), and the
> audition **wraps in one round** — you don't keep calling back the ones who didn't
> make it, forever.

---

> **This file follows the "structure standard" (`batch.md`) for all 5 archetype
> catalogs.** Same **6-section + loop-registry 5-cell mapping + one example**
> structure. The content here is Explore's; the shape of the cells (section order and
> names) is standardized on batch.md.
>
> **The 6-section standard**: ① Diagnostic signals / ② Slots / ③ Prompt skeleton /
> ④ Default verifier / ⑤ Default hardstop / ⑥ Accepted signal. After those comes the
> **loop-registry 5-cell mapping** table and **one example**.

---

## One-line definition

**Diverge into several options at once → score them against criteria → converge on
the best.** "Make N different ones and pick the best of them" is the heart of it.

Loop-spec fields: `archetype: explore`, `label: Explore`.

## ① Diagnostic signals (phrases that point to Explore)

When the classifier (`classifier.md`) finds these signals in the situation
sentence, it treats Explore as a candidate. The scorer ships an English keyword set;
for any other language the LLM reads the *meaning*.

- "several", "a few options", "make a few"
- "ideas", "candidates", "compare options"
- "pick one", "the best", "the strongest", "the top choice"
- "make N and pick the best", "generate and choose"
- "choices", "among several versions"

> ⚠ **Watch out for the confusion pair.** If the sentence also carries "all of them /
> each / 100 of them" — like "process *several* of them, each one" — it's a tie with
> **Batch** → fire the branch question: "Pick the *best* of several? (Explore) Or
> process all N items, *each one*? (Batch)". The key distinction — Explore makes
> several candidates and keeps only some (make many, keep few); Batch processes all N
> items with none skipped (keep as many as you made — no picking).

## ② Slots (4 blanks to ask the user)

The interviewer (`interviewer.md`) asks these 4 blanks as **plain-language
questions, posed in the user's own language at runtime**. The keys go straight into
the loop spec's `slots` object.

| Slot key | Plain-language question | Example answer |
|---|---|---|
| `generate_target` | "**What** should I make several of? (e.g. title candidates / copy / design mockups / ideas)" | YouTube video titles |
| `candidate_count` | "**How many** candidates should I generate? (the diverge count — leave blank for a conservative default of 8)" | 8 |
| `selection_criteria` | "**On what criteria** should I pick? Write 1–5. (e.g. click potential (CTR) · clarity · length)" | CTR potential, clarity, length |
| `final_count` | "**How many** should I keep at the end? (the converge count — leave blank for a conservative default of 3)" | 3 |

> ⚠ **`selection_criteria` (the picking criteria) is the blank a non-developer most
> often skips.** With no criteria and only "just the best one," selection drifts into
> **subjectivity ("this one grabs me")** — you can't explain why it won, and you
> can't reproduce it next time. If the criteria are blank the interviewer re-asks
> "what tells you it's 'the best'?", and if `candidate_count` · `final_count` are
> blank it offers conservative defaults (8 diverge / 3 converge). **Both the diverge
> count (`candidate_count`) and the final count (`final_count`) must be filled** so
> "how many to make and how many to cut to" is defined, which stops infinite
> diverging.

## ③ Prompt skeleton (the procedure with variables substituted)

The assembler (`assembler.md`) substitutes the slot values into the `{slot}`
placeholders to build the `skeleton` field.

```
1) Diverge {generate_target} into {candidate_count} options.
   Make them genuinely different (force diversity) — don't stamp out N
   near-identical variants. If {candidate_count} > cap, do NOT diverge —
   stop and report. (gate)
2) [score] Score every candidate on each of {selection_criteria}
   (per-criterion score + total). No subjective "this grabs me" verdicts —
   write a rationale and a score per criterion.
3) [converge] Keep only the top {final_count} by total.
4) [rationale] Alongside the selected {final_count}, log and present the
   reason each rejected candidate lost (which criterion it fell short on).
5) [verifier] Scoring runs in a pass SEPARATE from the flow that made the
   candidates (maker ≠ picker). Plus a diversity check — confirm the N
   candidates really differ, with no dupes/near-dupes mixed in, and penalize
   near-duplicate candidates.
6) [hardstop] Diverging ends in ONE round (no infinite diverging).
   "I don't like them, do N more" re-diverging happens only on explicit user request.
```

> Steps ④⑤ (verify · stop) are easy for a non-developer to forget → the assembler
> **auto-injects** the ④⑤ text below. The user only fills slots ①–③ and ④⑤ come along.

## ④ Default verifier (auto-injected — maker ≠ checker + diversity check)

> **Scorer separate from generator (maker ≠ picker)** + **a diversity check (do the
> N really differ — penalize dupes/near-dupes)**.

- **Why a separate scorer**: if the same flow that just made the candidates judges
  "which is best?", it scores its own pet option generously and misses the real best.
  So scoring runs in a pass **separate from the diverge**.
- **Why a diversity check**: the value of Explore is "seeing many genuinely different
  options." If the N candidates are really minor variants of the same sentence, there
  was no point making many and the pool to pick the best from is narrow. So
  **penalize dupes/near-dupes** to verify the N are truly diverse (this is Explore's
  own verification axis, distinct from Batch's "count-match").

## ⑤ Default hardstop (auto-injected — candidate-count cap + single round, both)

> **A candidate-count cap** (block entry past the diverge ceiling) · **one round (no
> infinite diverging)** — re-diverging only on explicit user request.

- **Candidate-count cap**: `candidate_count` is the diverge cost ceiling. If the
  requested count exceeds the ceiling, the diverge never starts.
- **One round (no infinite diverging)**: the most common Explore accident is "none of
  these grab me," pulling N more again and again — diverge endlessly and you burn
  time/cost while the decision stalls. So **diverging ends in one round by default.**
  Re-diverging (another N) isn't something the loop does on its own — **only on an
  explicit user request**.
- You need both together to stop "make more" from spinning endlessly.

## ⑥ Accepted signal (the observation that counts as done)

> **The selection result** + **a rejection-rationale log**.

Not "it feels like I picked the best" — it counts as "done" only when ① the final
`final_count` selections are actually produced and ② the reason each rejected
candidate lost (which criterion it fell short on) is logged (no soft completion).
Without the rejection rationale you can't explain or reproduce "why this one won,"
and selection collapses into subjectivity.

## loop-registry 5-cell mapping

| loop-registry cell | Value (`registry` field) |
|---|---|
| trigger (`trigger`) | manual `/command` run |
| gate (`gate`) | `candidate_count ≤ cap` (block entry past the diverge ceiling and report) |
| verifier (`verifier`) | §④ — scorer separate from generator (maker ≠ picker) + diversity check (penalize dupes/near-dupes) |
| hardstop (`hardstop`) | §⑤ — candidate-count cap · one round (no infinite diverging) · re-diverge only on explicit user request |
| accepted_signal (`accepted_signal`) | §⑥ — the selection result + a rejection-rationale log |

## Example — "Generate YouTube title candidates and pick the best"

| Slot | Value |
|---|---|
| `generate_target` | YouTube video titles |
| `candidate_count` | 8 (diverge) |
| `selection_criteria` | [CTR potential, clarity, length] |
| `final_count` | 3 (converge) |

Assembled result (summary):
- **skeleton**: diverge 8 titles (genuinely different) → stop if 8 > cap → [score]
  per-criterion CTR potential · clarity · length → [converge] keep the top 3 →
  [rationale] the 3 selected + the 5 rejected reasons logged → [verify] scoring runs
  in a pass separate from the diverge + a diversity check (penalize near-dupes) →
  [stop] end in one round, re-diverge only on explicit request.
- **registry.verifier**: scorer separate from generator (maker ≠ picker) + a
  diversity check (are the 8 really different — penalize dupes/near-dupes).
- **registry.hardstop**: candidate-count 8 cap · one round (no infinite diverging) ·
  re-diverge only on explicit user request.
- **registry.accepted_signal**: 3 final titles selected + a rejection-rationale log
  for the 5 rejected (the criterion each fell short on).

> The full loop-spec JSON for this example lives in `references/loop-spec-schema.md`
> and `tools/examples/explore/spec.json` (schema-validated).

## Related

- `references/loop-spec-schema.md` — the neutral spec contract these slots ·
  skeleton · registry land in
- `references/classifier.md` — the mirror of ① diagnostic signals (the SIGNALS
  dict) + the confusion-pair (explore ↔ batch) branch question
- `references/interviewer.md` — ② the slots as plain-language questions + the
  missing-slot re-asks (especially `selection_criteria` · `candidate_count` ·
  `final_count`)
- `references/assembler.md` — ③ skeleton substitution + the ④⑤ auto-injection rules
- `tools/check_safety.py` — static rejection (exit 2) when ④⑤ are missing
