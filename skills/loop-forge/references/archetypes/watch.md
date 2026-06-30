# Archetype catalog — Watch ⚠ most dangerous — external-action gate enforced

> Picture a **security guard in a watch room**. They keep an eye on a fixed area (the
> watch target), and when a defined thing happens (the condition), they take a
> promised action. But **they never decide on their own to open the door and let
> something out** (an outbound send/post) — first they show a preview or get a
> person's approval. A guard who trips the alarm on a false positive, or opens the
> door by mistake, causes an incident.

---

> **This file follows the "structure standard" (`batch.md`) for all 5 archetype
> catalogs.** Same **6-section + loop-registry 5-cell mapping + one example**
> structure. The content here is Watch's; the shape of the cells (section order and
> names) is standardized on batch.md.
>
> **The 6-section standard**: ① Diagnostic signals / ② Slots / ③ Prompt skeleton /
> ④ Default verifier / ⑤ Default hardstop / ⑥ Accepted signal. After those comes the
> **loop-registry 5-cell mapping** table and **one example**.
>
> ⚠ **This is the most dangerous of the five — which is exactly why the safety
> devices matter most here.** It's the only shape that touches outbound action
> (sending/posting), so ④ verifier nails down **"dry-run or human approval first."**
> A stamped Watch spec sets `registry.external_gate` to `dry_run` or `human_approval`
> (never `none`); if it's missing, `tools/check_safety.py` rejects it with **exit 2**
> (the external-action gate is enforced on that enum, so it works in any language).
> Stamping only (unattended launchd/cron scheduling is a non-goal) — a person runs
> the `/command`, and the condition/interval triggers inside it.

---

## One-line definition

**Watch a fixed target, and when a condition fires, take a promised action.** "Every
time one arrives / when it pops up / when something new comes in → notify · process"
is the heart of it. Any outbound action (sending email · posting to social etc.)
happens **only after a preview or human approval**.

Loop-spec fields: `archetype: watch`, `label: Watch`, **`external_action` defaults to
`true`** (conservative — only drop it to `false` when the interview clearly confirms
the action isn't outbound; even then, the ④ pre-action gate still runs).

## ① Diagnostic signals (phrases that point to Watch)

When the classifier (`classifier.md`) finds these signals in the situation
sentence, it treats Watch as a candidate. The scorer ships an English keyword set;
for any other language the LLM reads the *meaning*.

- "every time one arrives", "whenever a new one comes in", "when something new shows up"
- "when it pops up", "when it appears", "when it happens"
- "when detected", "when it's caught", "when it matches"
- "when a condition is met", "automatically when X"
- "auto-notify me", "send me an alert", "check and let me know"

> ⚠ **Watch out for the confusion pair.** If the sentence also carries "all of them /
> each / 100 of them" — like "summarize all the reviews *as they come in*" — it's a
> tie with **Batch** → fire the branch question: "Process the N already piled up *all
> at once*? (Batch) Or react *each time a new one arrives*? (Watch)". The key
> distinction — Batch sweeps a *finite list that's already gathered* once and ends;
> Watch keeps watching *what will arrive* and reacts whenever the condition fires.

## ② Slots (4 blanks to ask the user)

The interviewer (`interviewer.md`) asks these 4 blanks as **plain-language
questions, posed in the user's own language at runtime**. The keys go straight into
the loop spec's `slots` object.

| Slot key | Plain-language question | Example answer |
|---|---|---|
| `watch_target` | "**Where** should I watch? (e.g. an inbox / a specific folder / a board · channel / a sheet (Excel·Google Sheets))" | the inbox (Gmail) |
| `trigger_condition` | "**What, when seen,** should make me react? (the trigger condition — e.g. subject contains 'X' / a new file arrives / a number crosses a threshold)" | subject/body contains the keyword 'X' |
| `trigger_action` | "When the condition matches, **what action** should I take? (e.g. an on-screen notification / make a summary / **an outbound action** like sending email · posting)" | make a summary and notify on screen |
| `period_limit` | "**How often** should I check, and **at most how many actions per day**? (interval + daily cap — leave blank for a conservative default: 5-min interval · 20/day)" | check every 5 min · cap 20/day |

> ⚠ **If `trigger_action` is an outbound action (sending email · posting — anything
> that goes outward), set `external_action` to `true`** and have the interviewer ask
> once more: **"Preview (dry-run) before it goes out, or approve each one
> yourself?"** — that answer sets `registry.external_gate` to `dry_run` (auto-pass
> after preview) or `human_approval` (wait for a human OK), which drives the ④
> verifier's external gate. `period_limit` (interval · daily cap) is the blank a
> non-developer most often skips, so if it's blank offer conservative defaults (5-min
> interval · 20/day) — **you need an interval and a daily cap** to stop a flood
> (firing with no cooldown, thousands of actions a day).

## ③ Prompt skeleton (the procedure with variables substituted)

The assembler (`assembler.md`) substitutes the slot values into the `{slot}`
placeholders to build the `skeleton` field.

```
1) Poll {watch_target} at the {period_limit} interval, or receive its events.
2) [condition check] Does it match {trigger_condition}?
   · If not, take no action and go back to waiting.
3) [pre-action gate / verifier] Even when it looks like a match, do NOT act yet:
   · (false-positive guard) Re-confirm independently that {trigger_condition}
     really matches, once more.
   · (outbound) If {trigger_action} is an outbound send/post,
     ★ show a dry-run preview OR get human approval first, then execute. ★
     (Never send anything outward before the preview/approval passes.)
4) Execute {trigger_action}.
5) [record] Write an idempotency key (a dedup marker) for "this one is handled" →
   so the same trigger arriving again does not act twice.
6) [hardstop] If the daily action count hits the cap, or the gap since the last
   action is shorter than the cooldown, hold the action → go back to waiting.
```

> The ③ [pre-action gate] and ⑥ [stop] are the parts a non-developer most often
> forgets — and at the same time **the most dangerous parts of this shape** → the
> assembler **auto-injects** the ④⑤ text below. The user only fills slots ①–② and the
> external gate + flood protection come along.

## ④ Default verifier (auto-injected — pre-action gate + dry-run/approval first for outbound)

> **A pre-action gate (false-positive guard — independently re-confirm the condition
> really matches)** + **an outbound action (send/post) executes only after a dry-run
> preview or human approval passes**.

- **Why a pre-action gate**: acting on a single condition check means reacting to
  **false positives** (the things that matched by mistake). Outbound actions
  (email · posting) can't be undone once they leave. So just before acting, look once
  more — re-confirming the match in a check **separate from the original judgment**
  (maker ≠ checker).
- **Why dry-run / human approval**: outbound sends/posts are **irreversible**. The
  way email is drafted first and then a human sends it, an automated send executes
  **only after an independent gate (preview or human approval) passes**. A dry-run
  preview shows "here's what will go out" first; human-approval mode sends each one
  only after a person says OK.
- This gate **must** be present in a Watch spec — `tools/check_safety.py` rejects
  with **exit 2** when `archetype == watch` (or `external_action == true`) and
  `registry.external_gate` is not `dry_run` or `human_approval`. The check gates on
  the **enum**, not on prose, so it holds in any language.

## ⑤ Default hardstop (auto-injected — daily cap · cooldown · idempotency, all three)

> **A daily action cap** (at most N/day) · **a cooldown** (a minimum gap between
> consecutive triggers) · **dedup of repeat triggers (an idempotency key)**.

- **Daily cap**: the daily limit in `period_limit` is the day's cost/send ceiling.
  Once you hit the cap, stop acting and roll over to the next day — this stops
  unbounded action "when conditions pour in like a flood."
- **Cooldown**: even if the same condition fires several times in quick succession,
  hold the action when the gap since the last one is shorter than the cooldown — this
  stops rapid-fire / spammy action.
- **Idempotency key (dedup marker)**: even if the same trigger is caught twice during
  polling, the once-handled item is recorded by key so the second pass skips it —
  this stops duplicate action like "two alerts for the same email."
- You need all three together to stop "a loop that reacts endlessly to false
  positives and fires things outward" — the most dangerous Ralph Wiggum failure.

## ⑥ Accepted signal (the observation that counts as done)

> **A trigger log** + **action results** + **a false-positive rate**.

A monitor isn't "run once and done" — it keeps watching, so what counts isn't "done"
but **"running healthily,"** observed as: ① a log of when and what triggered, ② the
action result of each trigger recorded (sent / held / skipped), and ③ a
false-positive rate (the share that matched by mistake) tallied. A rising
false-positive rate is the signal to narrow `trigger_condition` again (no soft
completion, no flying blind).

## Connection — the basis for the external-action gate

This is the only shape that handles **outbound action**, so it ties directly into a
universal publishing-safety principle:

- **Outbound action = an independent gate.** The way external email is drafted first
  and a person reviews/sends it, an automated publishing loop is held to the same
  bar: an **independent verifier (maker ≠ checker)** — separate from the loop that
  *made* the content — judges it before it goes out. Watch's ④ pre-action gate is
  exactly that independent verifier, and the dry-run/human-approval choice is how the
  gate is passed.
- A pre-publish gate judges facts · tone · secrets independently before an unattended
  loop publishes. A Watch loop whose triggered action is an outbound send/post stands
  on the same line.

> So even a Watch loop built by a non-developer is born **with** a pre-publish
> independent gate + dry-run/approval. That's why the verifier auto-injection has its
> greatest value in this shape.

## loop-registry 5-cell mapping

| loop-registry cell | Value (`registry` field) |
|---|---|
| trigger (`trigger`) | condition/interval — fires when `{trigger_condition}` is met (or on the `{period_limit}` polling interval). (A person runs the `/command`; the condition/interval triggers inside it — unattended scheduling is a non-goal.) |
| gate (`gate`) | the pre-action gate — independent re-confirmation of the condition **+ if the action is outbound, a dry-run preview or human approval first** |
| verifier (`verifier`) | §④ — pre-action gate (false-positive independent re-confirmation) + outbound action executes only after dry-run/human approval passes |
| hardstop (`hardstop`) | §⑤ — daily action cap · cooldown (minimum gap between consecutive triggers) · dedup of repeat triggers (idempotency key) |
| accepted_signal (`accepted_signal`) | §⑥ — a trigger log + action results + a false-positive rate |

> Plus, for Watch (or any `external_action == true`): **`registry.external_gate ∈
> {dry_run, human_approval}`** (never `none`). This language-independent enum is what
> the static safety check enforces.

## Example — "Alert me when an email with keyword 'X' arrives"

| Slot | Value |
|---|---|
| `watch_target` | the inbox (Gmail) |
| `trigger_condition` | subject/body contains the keyword 'X' |
| `trigger_action` | make a summary and notify on screen (**not outbound → internal notification** by default) |
| `period_limit` | check every 5 min · cap 20/day |

Assembled result (summary):
- **external_action**: this example is an internal (on-screen) notification, so it
  may drop to `false` — but Watch's default is the conservative `true`, and **even
  when dropped to internal, the ④ pre-action gate (false-positive independent
  re-confirmation) still runs**. (If the action were "email the summary out," it
  would be `external_action: true` + a required dry-run/approval gate, i.e.
  `external_gate ∈ {dry_run, human_approval}`.)
- **skeleton**: poll the inbox every 5 min → match keyword 'X'? → [pre-action gate]
  independently re-confirm the real match (if outbound, dry-run/approve first) →
  notify the summary → write the idempotency key → [stop] check the 20/day cap ·
  cooldown, then wait.
- **registry.verifier**: pre-action gate (false-positive independent re-confirmation)
  + outbound action (send/post) executes only after a dry-run preview or human
  approval passes.
- **registry.hardstop**: 20/day cap · cooldown between consecutive triggers · dedup
  of repeat triggers via idempotency key.
- **registry.accepted_signal**: a trigger log (when, what fired) + action results
  (notified / held) + a tallied false-positive rate.

> The full loop-spec JSON for this example lives in `tools/examples/watch/spec.json`
> (includes the external-action gate; passes `check_safety.py`). For Watch the
> dry-run is **description only** (running a real poll could fire a real send — never
> sample it), per the dry-run-depth rule in `references/assembler.md`.

## Related

- `references/loop-spec-schema.md` — the neutral spec contract these slots ·
  skeleton · registry land in (includes the `external_action` field + the
  `registry.external_gate` enum)
- `references/classifier.md` — the mirror of ① diagnostic signals (the SIGNALS
  dict) + the confusion-pair (batch ↔ watch) branch question
- `references/interviewer.md` — ② the slots as plain-language questions + the
  missing-slot re-asks (especially the `trigger_action` outbound check ·
  `period_limit`)
- `references/assembler.md` — ③ skeleton substitution + the ④⑤ auto-injection rules
  + Watch dry-run depth (description only)
- `tools/check_safety.py` — static rejection (exit 2) when ④⑤ are missing, **and
  especially when the Watch external-action gate (`external_gate`) is absent**
