---
description: Turn a one-line repetitive task into a reusable, self-guarding slash command (loop-forge)
argument-hint: [one-line description of the task you keep doing by hand]
---

# /loop-forge

Hand the one-line situation in `$ARGUMENTS` to the **loop-forge** skill and run its
6-stage flow exactly as written in `skills/loop-forge/SKILL.md`:

1. **Entry** — read the situation from `$ARGUMENTS`. If empty, ask (in the user's
   language): "What task do you keep doing by hand? Describe it in one line."
2. **Diagnose** — classify it into one of the 5 loop shapes
   (Batch / Pipeline / Refine / Watch / Explore). Never invent a sixth.
3. **Interview** — ask the shape's slot questions in plain language; re-ask the
   output location, the hardstop inputs, and the eval criteria if left blank.
4. **Assemble + auto-inject safety + static check** — substitute the slots, inject the
   verifier (maker ≠ checker), the hardstop, and (for outbound actions) the
   external-action gate, then run `tools/check_safety.py`. The gate is
   **non-bypassable**: exit 2 bounces back to the interview.
5. **Dry-run preview** — show how it will run and get **explicit approval**. No
   approval, no stamping.
6. **Stamp** — render the reusable `/command` (and, optionally, the Portable Prompt)
   and tell the user how to run it.

This command is a thin entry point. The authoritative procedure, the 5 archetype
catalogs, the classifier, the interviewer, the assembler, the renderers, and the
deterministic safety gate all live under `skills/loop-forge/`. Follow `SKILL.md` —
do not re-implement the flow here.

> Non-goals (preserved): loop-forge does **not** schedule unattended runs
> (`launchd`/`cron`) and never publishes externally on its own. It stamps the reusable
> command and stops there.
