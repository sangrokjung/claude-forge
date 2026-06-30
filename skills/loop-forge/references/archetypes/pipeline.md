# Archetype catalog — Pipeline

> Picture a **factory assembly line**. A part moves through several workstations
> (stages) in a fixed order, and at the end of each station there's an exit checkpoint
> — "is this OK to send to the next station?" Only what passes the checkpoint moves
> on, and a finished product comes out at the end.

---

> **This file follows the 6-section structure standard set by `batch.md`.**
> ① Diagnostic signals / ② Slots / ③ Prompt skeleton / ④ Default verifier /
> ⑤ Default hardstop / ⑥ Accepted signal + the loop-registry 5-cell mapping + one
> example. The shape of the cells (section order and names) is standardized on
> batch.md; the content here is Pipeline's.

---

## One-line definition

**Pass through fixed stages A→B→C, in order.** Like "research it, write from that,
then proofread" — where **each stage's output is the next stage's input** in a
straight-line flow. That hand-off is the heart of it.

Loop-spec fields: `archetype: pipeline`, `label: Pipeline`.

## ① Diagnostic signals (phrases that point to Pipeline)

When the classifier (`classifier.md`) finds these signals in the situation
sentence, it treats Pipeline as a candidate. The scorer ships an English keyword
set; for any other language the LLM reads the *meaning*.

- "then", "after that", "use that to"
- "research it then write it up", "look it up then organize it"
- "in order", "one after another", "step by step"
- "do A then B then C", "A → B → C"
- "run it through", "pass it through", "hand it off to"
- "first do X, then later do Y"

> ⚠ **Watch out for the confusion pair.** If the sentence also carries "and then
> polish it more / make it nicer / draft and fix," it's a tie with **Refine** → fire
> the branch question: "Pass through fixed stages *once each*, in order? (Pipeline)
> Or repeat *the same thing* to make it better? (Refine)". The key distinction —
> Pipeline runs **different stages once each**; Refine runs **generate ↔ evaluate on
> the same target, many times**.

## ② Slots (3 blanks to ask the user)

The interviewer (`interviewer.md`) asks these 3 blanks as **plain-language
questions, posed in the user's own language at runtime**. The keys go straight into
the loop spec's `slots` object.

| Slot key | Plain-language question | Example answer |
|---|---|---|
| `stages` | "Which **stages** does it go through, in order? List the stage names with arrows. (e.g. research → draft → proofread)" | `[research, draft, proofread]` |
| `stage_io` | "**What does each stage take in, and what does it put out?** (what one stage puts out becomes the next stage's input)" | `{research → source list, draft → article, proofread → final copy}` |
| `final_artifact` | "**What do you hold at the very end, and where does it land?** (e.g. one `final.md`)" | the proofread article `final.md` |

> `stage_io` is not just an "inputs/outputs" memo — it's the **basis for the exit
> gates**. It defines "this stage must put out ○○ before the next stage earns the
> right to start," so if the user answers only "just chain them however," the
> interviewer pins down the connecting artifact between stages and re-asks.

## ③ Prompt skeleton (the procedure with variables substituted)

The assembler (`assembler.md`) substitutes the slot values into the `{slot}`
placeholders to build the `skeleton` field.

```
1) Run the first stage of {stages} → produce that stage's artifact as defined by
   {stage_io}.
2) [exit gate 1] Check that the artifact qualifies as input for the next stage
   (if it's empty or malformed, do NOT pass it on — report at the current stage).
3) Run the next stage → produce its artifact.
4) [exit gate N] At the end of every stage, run the same "next-stage input
   qualification" checkpoint.
   ... repeat to the end of {stages} (a gate at the end of each stage) ...
5) The final stage produces {final_artifact}.
6) [verifier] Review {final_artifact} in a SEPARATE pass — not "right after
   making it" (maker ≠ checker). At the same time, confirm that every stage's
   exit-gate pass was logged.
7) [hardstop] If a single stage fails twice, halt the pipeline and report
   "which stage got stuck and why" (do not proceed to the next stage).
```

> The exit gates (②④) and the final review (⑥) are easy for a non-developer to
> forget → the assembler **auto-injects** the ④⑤ text below. The user only fills
> ① (stages) · ② (I/O) · ③ (final artifact) and the gates · review · stop come along.

## ④ Default verifier (auto-injected — maker ≠ checker)

> **An exit gate at every stage** (next-stage input qualification) + **review of the
> final artifact at a point separate from its creator** (maker ≠ checker).

- **An exit gate at every stage**: between stages, check "is this result OK to start
  the next one with?" If an earlier stage puts out garbage, the next stage quietly
  makes *bigger* garbage out of it — so you block it **before the hand-off**
  (garbage-in prevention).
- **Final independent review**: if "the same flow that just made it" judges the
  final artifact, it can't see its own mistakes. So review runs in a pass
  **separate from generation**.
- You need both together to stop the Pipeline-specific failure where "a middle stage
  quietly went wrong and flows all the way through."

## ⑤ Default hardstop (auto-injected — per-stage retry cap + overall cap)

> **2 retries per stage** · **an overall time/cost cap** · **if one stage fails
> twice, halt the pipeline and report at the current stage**.

- **Per-stage retry cap**: when a stage fails, retry at most twice. Past 2 is
  banging your head on the same wall, so stop.
- **Overall cap**: put a time/cost ceiling on the whole pipeline — so it can't drag
  on forever no matter how many stages there are.
- **Halt + report on 2 failures**: don't force your way to the next stage; report
  **which stage got stuck and why** so a person can see it, and stop (no silent
  failure).

## ⑥ Accepted signal (the observation that counts as done)

> **The final artifact exists** + **a pass log for every gate**.

Not "it feels like I went through all the stages" — `final_artifact` must actually
exist and **every stage's exit gate must be logged as passed** before it counts as
"done" (a skipped gate anywhere = incomplete).

## loop-registry 5-cell mapping

| loop-registry cell | Value (`registry` field) |
|---|---|
| trigger (`trigger`) | manual `/command` run |
| gate (`gate`) | each stage's exit gate — proceed only when the next-stage input qualification passes |
| verifier (`verifier`) | §④ — an exit gate at every stage (input qualification) + independent review of the final artifact (maker ≠ checker) |
| hardstop (`hardstop`) | §⑤ — 2 retries per stage · overall time/cost cap · halt the pipeline and report at the current stage if one stage fails twice |
| accepted_signal (`accepted_signal`) | §⑥ — the final artifact exists + a pass log for every gate |

## Example — "Research a topic → draft → proofread"

| Slot | Value |
|---|---|
| `stages` | `[research, draft, proofread]` (3 stages) |
| `stage_io` | `{research → source list, draft → article, proofread → final copy}` |
| `final_artifact` | the proofread article `final.md` |

Assembled result (summary):
- **skeleton**: run research → produce a source list → [exit gate 1: is the source
  list empty / malformed?] → write the draft (input = source list) → produce an
  article → [exit gate 2: does the article qualify as a draft?] → proofread (input =
  article) → produce `final.md` → [verify] review `final.md` independently + confirm
  every gate's log → [stop] halt and report if one stage fails twice.
- **registry.verifier**: an exit gate at every stage (next-stage input
  qualification) + review of the final `final.md` in a pass separate from its creator
  (maker ≠ checker).
- **registry.hardstop**: 2 retries per stage · overall time/cost cap · halt the
  pipeline and report at the current stage if one stage fails twice.
- **registry.accepted_signal**: `final.md` exists + a pass log for all three stages'
  exit gates (research · draft · proofread).

> The full loop-spec JSON for this example lives in
> `tools/examples/pipeline/spec.json` (schema-validated).

## Related

- `references/loop-spec-schema.md` — the neutral spec contract these slots ·
  skeleton · registry land in
- `references/classifier.md` — the mirror of ① diagnostic signals (the SIGNALS
  dict) + the confusion-pair (pipeline ↔ refine) branch question
- `references/interviewer.md` — ② the slots as plain-language questions + the
  missing-slot re-asks (especially `stage_io` · `final_artifact`)
- `references/assembler.md` — ③ skeleton substitution + the ④⑤ auto-injection rules
- `references/archetypes/batch.md` — the source of the 6-section structure standard
- `tools/check_safety.py` — static rejection (exit 2) when ④⑤ are missing
