# Paste this prompt into your agent to run it (fill the inputs as the body indicates)

> Native custom-prompt stamping is deprecated and not guaranteed to work (see codex-prompt-mechanism.md), so this output is a **paste-able prompt** — paste the whole body below into your agent session (interactive, or `codex exec '...'`). The skeleton · verifier · hardstop · done signal are 100% identical to the Claude Code `/review-summary` command; the only difference is the invocation (slash vs. paste).

---

# review-summary — bulk 3-line review summary (Batch)

> Analogy: a factory conveyor belt — parts (reviews) run over one workstation (the 3-line summary) one at a time, each treated the same, and you count what came out at the end. You only build the workstation once; the conveyor repeats the rest.

## Input

The default input is `a reviews CSV (reviews.csv)`. To run it on different input, edit the input source in the procedure below to that value. (When stamped as a native custom prompt, the input comes in via `$ARGUMENTS`/`$1` — but that path is deprecated, see codex-prompt-mechanism.md §4.)

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

## How to run (paste)

Copy the whole block from "review-summary —" through "Done signal" and paste it into your agent session (interactive, or `codex exec '...'`) to run. To reuse the same loop on different input, change only the input source and paste again. The safety ceilings (budget · count · cooldown) cannot be raised by paste arguments.
