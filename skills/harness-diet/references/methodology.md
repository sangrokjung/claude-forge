# harness-diet methodology — why these budgets, and what the field runs taught us

Part of Claude Forge — github.com/sangrokjung/claude-forge (skills/harness-diet)

## 1. Why always-load size is the metric that matters

Two official anchors:

- CLAUDE.md: *"target under 200 lines per CLAUDE.md file. Longer files consume more context and
  reduce adherence"* (docs.claude.com/en/docs/claude-code/memory).
- Rules: *"Rules without `paths` frontmatter are loaded at launch with the same priority as
  `.claude/CLAUDE.md`"* (same page). Your rules directory can quietly become a second, much
  larger CLAUDE.md.
- Attention economics: *"LLMs have an 'attention budget' ... Every new token introduced depletes
  this budget"* (anthropic.com/engineering/effective-context-engineering-for-ai-agents).

The 8KB/file and 100KB/total defaults are operational values from a mature harness (100+ rules,
30+ sessions/day). They are ratchet points, not physics; pick numbers and enforce them.

## 2. Growth mechanics (measured on one harness, 6 months of git history)

- Growth is **automatic**: an auto-commit-on-edit pipeline meant 71% of rule commits were
  frictionless appends. Reduction was **manual**: 6 deliberate diet campaigns in 6 months.
  Commit ratio growth:reduction ≈ 60:1.
- Natural growth ran +70KB/month. After each diet, regrowth resumed at ~+6KB/month while the
  discipline held, and the cohort had previously peaked at 2.2x budget.
- Supply sources by added bytes: incident post-mortems (34%), leadership directives transcribed
  in full (28%), feature specs living inside rule bodies (24%). The "one-line rule per
  correction" pattern was NOT the problem (11% of commits, 6% of bytes) — narratives were.
- Conclusion: a diet is surgery, not a cure. Sustainability = automation of the *brake*
  (edit-time advisory + periodic strict audit), not bigger surgeries.

## 3. Classification decision tree

For each always-loaded rule, in order:

1. Is it needed in literally every session (tone, security boundary, routing index)? Keep
   always-loaded; diet the body.
2. Does it only matter when specific files are touched (SQL migrations, a config file, a
   directory)? Path-scope it. Remember: `paths` fires on file access, not on utterances; a rule
   whose trigger is what the user says cannot be path-scoped.
3. Is its real trigger a deterministic hook (a detector that fires on a pattern)? Let the hook
   inject "Read <rule> first" and convert the rule to conditional. This is the safest
   conversion: hook triggers are more reliable than utterance matching.
4. Is it a task procedure? Convert to a skill (official guidance: *"For task-specific
   instructions that don't need to be in context all the time, use skills instead"*).
5. Otherwise: migrate narrative to a reference file, keep the verdict skeleton.

When converting away from always-load, check what the rule's description promises: conditional
rule descriptions are not injected into every session. If the rule was the only carrier of a
prohibition, back the one-line prohibition up in a surface that still loads (or a deny rule /
deterministic hook, which is stronger anyway).

## 4. Byte accounting worksheet

For each file: record `before_bytes`, itemize per-block `est_bytes_saved` from *measured* line
ranges (`sed -n 'A,Bp' file | wc -c`), and compute `projected_bytes`. Two frauds to catch:

- **Over-attribution**: an estimate larger than the whole line range it claims to remove.
- **Double counting**: two proposals claiming overlapping ranges.

A verification pass should re-measure every claim. In one field run, 4 of 17 proposals
over-attributed savings; the totals only reconciled after re-measurement.

## 5. Verification lens design

Run two independent lenses, ideally by an agent that did not write the diet:

- **Loss lens**: does the slim body still contain every load-bearing literal? Use
  `preservation_check.py extract` BEFORE the edit, prune intended migrations from the manifest,
  `verify` after. Deterministic string checks out-perform judgment here: in one run the maker
  reported "kept verbatim" while the check found two missing qualifiers (a scope-limiting
  clause and a 24-hour deadline).
- **Efficacy lens**: is the saving real? Re-run the audit; confirm reference files are lazily
  read (no `@path` imports of them in loaded files — imported files still enter context at
  launch); confirm the projected total actually lands under budget.

## 6. Team-surface direction (multi-machine / team distribution)

If your rules are mirrored to teammates but your `~/.claude/CLAUDE.md` is personal, then
"delete from the rule, it's duplicated in CLAUDE.md" removes the content from every teammate's
context while keeping it only in yours. Dedup direction: **keep the shared surface (rules),
pointer-ize the private one.** Check `audience`/mirroring before any dedup deletion.

## 7. Atomicity

Reference appends and body slimming must land in the same commit (or at minimum, appends
first). If an auto-commit hook pushes the slim body the moment you write it, the window where
mirrors see "slim body, no reference content" is a real content hole. Field fix: batch-commit
the reference files immediately after, and note the hazard in the diet run log.

## 8. Field results (one harness, four rounds)

| Round | Action | Result |
|---|---|---|
| 1-3 | reference migration of 3 oversized rules | -33KB cumulative |
| 4 | 5-file migration + 4 conversions (path-scope / hook-injected / skill) | 146.3KB -> 100.6KB (-31%), 23 -> 19 always-loaded files, zero governance loss (deterministic checks + fresh checker, CRITICAL findings: 0) |

Residual over-budget files can be legitimate: a routing index whose every keyword is a routing
signal, or a norms document that just gained fresh directives. Document them as exceptions; the
edit-time guard keeps the pressure on.
