---
name: harness-diet
description: Measure and shrink the always-loaded context of a Claude Code harness (CLAUDE.md + rules without paths frontmatter) back under budget — migrate narrative to reference files, convert rules to path-scoped or skill-triggered loading, and verify zero governance loss with deterministic preservation checks. Use on "harness diet", "context diet", "rules diet", "CLAUDE.md too long", "always-load budget", "trim my rules", "context bloat", "하네스 다이어트", "룰 다이어트", "컨텍스트 다이어트", "always-load 줄여줘". Not for one-off prose editing or project docs cleanup.
license: MIT
metadata:
  category: harness-maintenance
  phase: v1
---

# harness-diet — put your always-loaded context back under budget

> A harness gains weight automatically (every incident note, every boss directive, every fix lands
> as another paragraph in an always-loaded rule) but only loses weight when someone runs a diet.
> Field measurement on a mature harness: growth-to-reduction commit ratio of ~60:1, natural growth
> of ~70KB/month, and adherence degrading as the pile grows. Anthropic's guidance is blunt:
> *"target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce
> adherence"*, and rules without `paths` frontmatter load *"with the same priority as CLAUDE.md"*
> — every session, every token ([memory docs](https://docs.claude.com/en/docs/claude-code/memory)).

**Result you should expect**: one field run took a harness from 146KB always-loaded (143% of
budget) to 100.6KB (98%) with **zero governance loss** — every killswitch, decision table,
trigger keyword, and canonical command verified present after the diet.

## Budgets (defaults — override via flags)

| Metric | Budget | Why |
|---|---|---|
| CLAUDE.md | < 200 lines | Anthropic official guidance |
| Per always-loaded rule file | 8,192 B | Keeps any single rule scannable; forces narrative out |
| Total always-loaded rules | 102,400 B | Attention-budget ceiling; beyond this, adherence drops |

> **Bundled script paths**: commands below use `$HOME/.claude/skills/harness-diet/…` (the
> `install.sh` layout). For marketplace (`/plugin install`) installs, resolve under
> `${CLAUDE_PLUGIN_ROOT}/skills/harness-diet/…` instead. The scripts are stdlib-only Python;
> if unavailable, perform the step manually from the described contract.

## Phase 0 — Measure

```bash
DIET="$HOME/.claude/skills/harness-diet"   # or "${CLAUDE_PLUGIN_ROOT}/skills/harness-diet"
python3 "$DIET/scripts/harness_diet_audit.py"            # human summary
python3 "$DIET/scripts/harness_diet_audit.py" --json     # machine output
python3 "$DIET/scripts/harness_diet_audit.py" --strict   # exit 2 if over budget (CI/ratchet)
```

Auto-discovers `./.claude/rules`, `~/.claude/rules`, and CLAUDE.md files at project/user level.
A rule is **always-loaded** iff its YAML frontmatter has no `paths:` key.

## Phase 1 — Classify every always-loaded rule

Walk the list from largest to smallest and pick one bucket per file:

1. **Keep always-loaded** — cross-cutting behavior needed in *every* session (tone, security
   boundaries, routing indexes). Diet the body (Phase 2) but keep the load class.
2. **Path-scope** — the rule only matters when specific files are touched. Add `paths:` globs.
   ⚠ Path scoping fires on *file access*, never on spoken keywords. A rule triggered by what the
   user *says* cannot be path-scoped. ⚠ No literal brackets in globs (`[locale]` parses as a
   character class and silently never matches).
3. **Convert to skill / hook-injected** — task-specific procedure? Official guidance: *"use
   skills instead"*. Best case: the rule's real trigger is already a deterministic hook — have
   the hook inject "Read <rule> first" into context and drop the always-load.
4. **Migrate narrative to reference** — the default for oversized keepers (Phase 2).

## Phase 2 — Migrate (block-level, never prose compression)

For each oversized file:

1. **Extract a preservation manifest first** (before touching anything):
   ```bash
   python3 "$DIET/scripts/preservation_check.py" extract rules/big-rule.md > /tmp/big-rule.manifest.json
   ```
2. **Append** the outgoing blocks to `references/<name>-ref.md` (or your repo's reference dir),
   verbatim under a dated section header. Append *before* rewriting the rule body, and commit
   both together — a slimmed body pushed without its reference content is a content hole for
   every mirror that pulls in between.
3. **Rewrite the rule body**: keep the verdict skeleton (what to do / never do), leave a one-line
   pointer to the reference for the "why" and the war stories.

**Must stay in the body** (never migrate): CRITICAL/IMPORTANT banners and their verdicts,
decision tables, trigger keywords and agent names (they are a routing index, not prose),
killswitch env vars, canonical command lines, IDs and threshold values.

**Migrate aggressively**: incident narratives, measurement history, duplicated explanations of
the same point, long example blocks, anything already present in the reference file.

## Phase 3 — Verify (two lenses, fresh checker)

1. **Loss lens (deterministic)**:
   ```bash
   python3 "$DIET/scripts/preservation_check.py" verify rules/big-rule.md /tmp/big-rule.manifest.json
   ```
   Exit 2 = something load-bearing got migrated. Restore it before proceeding. Review the
   manifest by hand first — prune entries that were *intended* to move.
2. **Efficacy lens**: re-run the audit; recompute the total; confirm the savings are real
   (reference files are lazily `Read`, not `@`-imported — check the rule bodies contain no
   `@path` imports of the reference, or the "savings" still load at launch).
3. **Fresh checker**: hand the diff to an independent reviewer that didn't write it (pairs with
   the `review-loop` skill). Diets fail quietly: a plausible-looking slim body missing one
   qualifier is exactly what the maker cannot see.

## Phase 4 — Guard (keep it off)

A diet without a guard regrows. Ship-with options in `$DIET/hooks/`:

- `rules-budget-guard.sh` — PostToolUse (`Edit|Write`) advisory: the moment a rule edit pushes a
  file past budget, the editing session gets a context note telling it to migrate, not append.
  Non-blocking by design — a blocking pre-commit gate silently stalls auto-commit pipelines.
- Re-run `--strict` weekly (cron, session-start dispatcher, or CI) and surface the report only
  when over budget.

## Anti-patterns (each one cost a real harness a failed round)

| Anti-pattern | Why it fails |
|---|---|
| Prose compression ("tighten the wording") | Trigger keywords, guru names, stage names *are* the routing index. A compression pass that saved 12% destroyed 70% of routing signals and was fully reverted. Move blocks; don't rewrite sentences. |
| Dedup toward a private file | If rules are distributed to a team but `~/.claude/CLAUDE.md` is one person's, "delete from rules, it's already in CLAUDE.md" deletes it from every teammate's context. Dedup toward the *shared* surface. |
| Slim body committed, reference append not | Mirrors pull a body full of dangling pointers. Commit both in one change. |
| Trusting the maker's "everything preserved" claim | Extract the manifest before the edit and verify after. Field run: the maker claimed "6 bullets kept verbatim"; the deterministic check found two qualifiers gone. |
| Treating one diet as the fix | Growth is automatic; reduction is manual. Without the guard, one measured harness regrew from 145KB toward its 220KB peak within weeks. |

## References

- `references/methodology.md` — budget rationale, growth mechanics, byte-accounting worksheet,
  verification lens design, worked field results.
