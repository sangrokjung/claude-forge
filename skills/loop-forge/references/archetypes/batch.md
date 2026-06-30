# Archetype catalog — Batch

> Picture a **factory conveyor belt**. You feed N parts (items) one at a time over a
> single workstation (the task), each gets the same treatment, and at the end you
> count what came out. You only have to build one good workstation — the conveyor
> handles the repetition.

---

> **This file is the "structure standard" for all 5 archetype catalogs.** The other
> four — pipeline · refine · watch · explore — follow the **exact same 6-section
> layout + loop-registry 5-cell mapping + one example** as below. Each file fills in
> its own shape's content, but the shape of the cells (section order and names) is
> standardized on batch.md.
>
> **The 6-section standard**: ① Diagnostic signals / ② Slots / ③ Prompt skeleton /
> ④ Default verifier / ⑤ Default hardstop / ⑥ Accepted signal. After those comes the
> **loop-registry 5-cell mapping** table and **one example**.

---

## One-line definition

**Run the same task across N items, all of them.** "One list, top to bottom, each
item treated the same" is the heart of it.

Loop-spec fields: `archetype: batch`, `label: Batch`.

## ① Diagnostic signals (phrases that point to Batch)

When the classifier (`classifier.md`) finds these signals in the situation
sentence, it treats Batch as a candidate. The scorer ships an English keyword set;
for any other language the LLM reads the *meaning*, so don't rely on surface words.

- "100 of them", "process N items", "run through all N"
- "all of them", "summarize them all", "every single one"
- "each one", "one by one", "for every item"
- "this list", "the whole list", "the entire set"
- "in bulk", "all at once", "go through them"

> ⚠ **Watch out for the confusion pairs.** If the sentence also carries "every time
> one arrives / when a new one shows up / as they come in," it's a tie with
> **Watch** → fire the branch question: "Process the N you have *all at once*?
> (Batch) Or react *each time a new one arrives*? (Watch)". If it carries "pick the
> *best* of several," it's a tie with **Explore** → "Process all N items, none
> skipped? (Batch) Or generate several and keep only the best? (Explore)".

## ② Slots (4 blanks to ask the user)

The interviewer (`interviewer.md`) asks these 4 blanks as **plain-language
questions, posed in the user's own language at runtime**. The keys go straight into
the loop spec's `slots` object.

| Slot key | Plain-language question | Example answer |
|---|---|---|
| `input_source` | "**Where** are the N items to process? (a folder / a sheet (Excel·Google Sheets) / a list of links / a database)" | a reviews CSV (`reviews.csv`) |
| `per_item_task` | "For **each single item**, what should I do?" | summarize one review into 3 lines |
| `output_format` | "**Where and in what form** should the results land? (e.g. a `summary.md` table / a new folder / printed to screen)" | a `summary.md` table (rows = reviews, columns = excerpt · 3-line summary) |
| `max_items` | "For safety, **at most how many** should I process? (the budget ceiling — leave blank for a conservative default of 50)" | 100 |

> `max_items` is not just a count — it's a **budget ceiling**. Item count *is* cost,
> so if the user answers only "just do all of them," the interviewer re-asks for the
> ceiling, and if it's left blank it offers the conservative default (50).

## ③ Prompt skeleton (the procedure with variables substituted)

The assembler (`assembler.md`) substitutes the slot values into the `{slot}`
placeholders to build the `skeleton` field.

```
1) Load the list from {input_source} and count the total N.
   If N > {max_items}, do not process — stop and report. (gate)
2) For each item: perform {per_item_task} → accumulate the result.
   (Work item-by-item — one item's failure must not block the next.)
3) Save as {output_format}.
4) [verifier] Count-match input N against output N (flag any missing/duplicate).
   Then pick a random K = min(5, N) and re-check them independently in a
   SEPARATE pass — not "right after making them" (maker ≠ checker).
5) [hardstop] 3 failures on a single item → skip just that item and log it
   (do not stop the whole run). If the cumulative failure rate passes 20%,
   abort at that point and report.
```

> Steps ④⑤ (verify · stop) are the ones a non-developer most often forgets → the
> assembler **auto-injects** the ④⑤ text below. The user only fills slots ①–③ and
> ④⑤ come along for free.

## ④ Default verifier (auto-injected — maker ≠ checker)

> Count-match input N against output N (flag missing/duplicate) + re-check a random
> K **in a separate pass, not right after generation (maker ≠ checker)**.

- **Why maker ≠ checker**: if the same flow that just produced the answers judges
  "did this go well?", it can't see its own mistakes. So verification runs in a pass
  **separate from generation**.
- The count-match catches "silent drops/duplicates" (one form of the Ralph Wiggum
  failure), and the random-K independent re-check samples for the "row count is
  right but the content is wrong" case.

## ⑤ Default hardstop (auto-injected — budget AND failure ceiling, both)

> `max_items` **budget cap** (block entry past the ceiling) · **3 failures per item
> → skip + log** (not a full stop) · **abort when the cumulative failure rate
> exceeds 20%**.

- **Budget**: `max_items` is the cost ceiling. If N exceeds it, the run never
  starts.
- **Failure ceiling**: when one item fails 3 times, skip just that item and record
  it (don't stop everything). But a **cumulative failure rate over 20%** signals
  "something is fundamentally wrong," so abort immediately.
- You need both together to stop "a loop that quietly breaks while eating money."

## ⑥ Accepted signal (the observation that counts as done)

> **N rows present** in the output + a **count of the failure log (skip list)**.

Not "it feels like I did them all" — the output file must actually contain N rows,
and the list of skipped items must be recorded, before it counts as "done" (no soft
completion).

## loop-registry 5-cell mapping

| loop-registry cell | Value (`registry` field) |
|---|---|
| trigger (`trigger`) | manual `/command` run |
| gate (`gate`) | `N ≤ max_items` (block entry past the ceiling and report) |
| verifier (`verifier`) | §④ — count-match input N vs output N + random-K independent re-check (maker ≠ checker) |
| hardstop (`hardstop`) | §⑤ — `max_items` budget cap · 3 failures per item → skip + log · abort when cumulative failure rate > 20% |
| accepted_signal (`accepted_signal`) | §⑥ — N rows present in output + count of the failure (skip) log |

## Example — "Summarize 100 shop reviews"

| Slot | Value |
|---|---|
| `input_source` | reviews CSV (`reviews.csv`) |
| `per_item_task` | summarize one review into 3 lines |
| `output_format` | a `summary.md` table (rows = reviews, columns = excerpt · 3-line summary) |
| `max_items` | 100 |

Assembled result (summary):
- **skeleton**: load N from `reviews.csv` → stop if N > 100 → summarize each review
  into 3 lines and accumulate → save the `summary.md` table → [verify] count-match
  input N vs output N + re-check a random 5 independently → [stop] skip after 3
  failures, abort if failure rate > 20%.
- **registry.verifier**: count-match input N vs output N + independent re-check of a
  random K (maker ≠ checker).
- **registry.hardstop**: `max_items` 100 budget cap · 3 failures per item → skip ·
  abort when cumulative failure rate > 20%.
- **registry.accepted_signal**: `summary.md` has 100 rows (or N − skipped rows) +
  a count of the skip list.

> The full loop-spec JSON for this example lives in `references/loop-spec-schema.md`
> §4 and `tools/examples/batch/spec.json` (schema-validated).

## Related

- `references/loop-spec-schema.md` — the neutral spec contract these slots ·
  skeleton · registry land in
- `references/classifier.md` — the mirror of ① diagnostic signals (the SIGNALS
  dict) + the confusion-pair branch questions
- `references/interviewer.md` — ② the slots as plain-language questions + the
  missing-slot re-asks (especially `output_format` · `max_items`)
- `references/assembler.md` — ③ skeleton substitution + the ④⑤ auto-injection rules
- `tools/check_safety.py` — static rejection (exit 2) when ④⑤ are missing
