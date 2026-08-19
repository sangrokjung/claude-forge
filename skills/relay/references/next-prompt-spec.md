# Relay baton — next-prompt spec (SSOT)

> Think of a relay race handoff: a well-placed baton lets the next runner start without breaking stride.
> This document is the single source of truth for the structure and authoring rules of the baton (the
> next-session handoff prompt). `relay-write-baton.sh` stamps out the skeleton, and SKILL.md's model prose
> pass fills in §2/§4 following these rules.

## Core principles (conclusion first)

- **MISSION-first**: the baton is oriented toward **"what to do next,"** not a "log of what was done." §1 matters most.
- **Facts stay verbatim**: facts like branch, uncommitted count, plan progress come **directly** from the
  collect JSON (§6 snapshot). Never retype from memory.
- **Relaxed-expert tone**: write like explaining to a colleague at the next desk, politely but not stiffly.
  Prose generation should use the **Sonnet** model tone.
- **Skeleton first, prose later**: even at 95% context, the skeleton (§0, §1, §3, §5, §6 below) must always
  be written. Add §2/§4 prose if there's headroom.

## 7-section template

### §0. The `/compact` one-liner (in-place mode only)
- The `/compact <focus>` line the user will **paste in as-is**. Wrap it in a code fence.
- In new-session mode, paste the **entire baton** into the new session instead of §0.
- The skill/scripts never run `/compact` directly — they only **produce** the one-liner.

### §1. MISSION (next task) — skeleton required
- NEXT_TASK as an **imperative** sentence.
- `Completion:` — a **binary** (done/not-done) one-liner.
- `First actions:` — 1-3 concrete steps. Prefer plan's next_unchecked / session_summary.next_steps / tasks
  items; if none, write "(needs to be defined)".

### §2. Context needed (task-filtered KEEP only) — prose
- Apply the **relevance filter** below. Keep only items that pass KEEP.
- Source tags: `[from-code]` (confirmed from a file) vs. `[from-claude]` (inferred).

### §3. Current state — skeleton required
- Branch, N uncommitted, plan k/n. Include blockers if any. All verbatim from the collect JSON.

### §4. Repro pitfalls / gotchas — prose
- Traps that are easy to re-hit on the next task (missing env vars, needs a cache clear, order-dependent steps, etc.).
- If none, write "no notable pitfalls."

### §5. Start command — skeleton required
- Must include at least one **absolute path** (a `cd <abs cwd>` line), followed by `git status`, etc.

### §6. Reference (for recovery) — skeleton required
- Only the **path** to the collect JSON snapshot. No inline bulk dump — recovery means Reading that file.

## Relevance filter rules (for writing §2)

Process each candidate context item against NEXT_TASK using these three tiers:

1. **KEEP** — overlaps with NEXT_TASK's keywords or file paths; keep it verbatim.
2. **One-line summary** — tangential; compress to one line.
3. **DROP** — irrelevant; discard (exploration logs, resolved errors, side conversation).

## Prose file format (write-baton `$4`)

When the model writes prose, save it to a temporary markdown file and pass it as the 4th argument to
`relay-write-baton.sh`.

- Use a single-line marker `---§4---` to split: **above = §2 body**, **below = §4 body**.
- If the marker is absent, the whole file becomes the §2 body.
- The marker is a deterministic splice point for the prose.

Example:
```
[from-code] The payment flow in src/pay.ts goes webhook -> settlement. Stripe secret is env-only.
[from-claude] Refund path is presumed unimplemented.
---§4---
- STRIPE_SECRET_KEY missing -> 500. Check .env.local.
- Run `pnpm build` once before testing (stale cache).
```

## Craft rules (summary)

- Conclusion first, then impact, then evidence, then recommendation (CEO-briefing style).
- Facts verbatim, inferences tagged `[from-claude]`.
- Always emit absolute paths (no relative paths, no unexpanded `~`).
- Relaxed-expert tone; prose written by Sonnet.
