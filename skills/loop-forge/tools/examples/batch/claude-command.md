---
description: Summarize 100 shop reviews into 3 lines each (Batch loop)
argument-hint: [input file path — blank for reviews.csv]
---

# /review-summary — bulk 3-line review summary (Batch)

> Analogy: a factory conveyor belt — parts (reviews) run over one workstation (the 3-line summary) one at a time, each treated the same, and you count what came out at the end. You only build the workstation once; the conveyor repeats the rest.

## Input: $ARGUMENTS

If $ARGUMENTS is set, use it as the input source (e.g. a different reviews file path); if empty, use the default `a reviews CSV (reviews.csv)`. Swap only the input to reuse the same loop.

## Procedure

1) Load the list from the reviews CSV (reviews.csv) and count the total N. If N > 100, do not process — stop and report.
2) For each review: summarize one review into 3 lines → accumulate the result.
3) Save as a summary.md table (rows = reviews, columns = excerpt · 3-line summary).
4) [verifier] Count-match input N against output N (flag missing/duplicate), then re-check a random K = min(5, N) in a SEPARATE pass, not right after generation (maker ≠ checker).
5) [hardstop] 3 failures on one item → skip + log; if the cumulative failure rate passes 20%, abort.

## Verifier (auto)

> count-match input N vs output N (flag missing/duplicate) + re-check a random K in a separate pass, not by the generator (maker ≠ checker)

If the same flow that just produced the summaries grades "did this go well?", it can't see its own mistakes → verification runs in a **pass separate from generation** (maker ≠ checker). The count-match catches silent drops/duplicates, and the independent re-check of a random sample catches the "row count is right but the content is wrong" case.

## Hardstop

> max_items 100 budget cap · 3 failures per item → skip + log (not a full stop) · abort when cumulative failure rate > 20%

`max_items` (100) is the cost ceiling, so if N exceeds it the run never starts. When one item fails 3 times, skip just that item and log it (don't stop everything). But a **cumulative failure rate over 20%** signals something is fundamentally wrong, so stop immediately — this blocks "a loop that quietly breaks while eating money."

## Done signal

> N rows present in summary.md + a count of the failure log (skip list)

Not "it feels like I did them all" — `summary.md` must actually hold N rows (or N − skipped), and the list of skipped items must be recorded, before it counts as "done" (no soft completion).

## How to run

Run `/review-summary` (manual /review-summary run). To run it on a different file: `/review-summary <path to reviews file>`. For safety it processes at most 100 items at a time, and that ceiling cannot be raised by a call argument.
