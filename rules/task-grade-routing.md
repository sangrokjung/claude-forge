---
name: task-grade-routing
load: always
audience: team
sensitivity: L1
category: verification
critical: true
description: Per-grade documentation and verification obligations for /workflow-classify's S/M/L/XL sizes — what to write before code, and how many independent lanes gate completion.
---

# Task Grade Routing (CRITICAL)

> Analogy: a building permit office doesn't ask for the same paperwork for a doorbell repair and a
> load-bearing wall removal. The size of the job sets the size of the record. This rule maps
> `/workflow-classify`'s S/M/L/XL sizes to that record, and to how many independent lanes have to
> approve the change before it counts as done.

## The table

| Grade | Documentation | Verification |
|---|---|---|
| S | No persistent docs. Keep goal, constraints and done-when inline for the session | Targeted check |
| M | Micro-spec, 4 items: Goal / Non-goals / Acceptance / Test | Targeted check, plus 1 independent review lane on any behavioural change |
| L | Permanent spec and plan, written and approved before code | 1 adversarial lane (`rules/adversarial-review.md`) |
| XL | Full spec, decision record, rollout/rollback, and an approval gate before implementation | 2+ independent lanes: correctness plus the risk-specific angle |

## Escalation floor

Regardless of size:

- Auth, payments, PII, RLS policies, secrets boundaries, or irreversible deploys start at XL.
- Non-destructive schema or API contract changes start at L.

Escalate up, never down. A change that looks XS but touches one of these is XL from the first
draft, not XL after a downgrade gets caught later.

## Reviewer death is not a pass

A checker that crashes, times out, or returns nothing has verified nothing, at any grade. Dispatch
a fresh checker; the maker reviewing its own change is not a substitute for the reviewer that died.
See `rules/adversarial-review.md`.

## Using this with /workflow-classify

`/workflow-classify` sizes a task from repo signals. This rule answers what that size leaves open:
what to write down, and how many independent eyes look at it before the change is done. The
command's classification report prints both fields for the grade it assigns.

## Related

- `commands/workflow-classify.md` — sizing procedure and pipeline recommendation
- `rules/adversarial-review.md` — the three verdicts, and what checker independence means
- `skills/review-loop/SKILL.md` — how the adversarial loop is actually run
- `agents/adversarial-reviewer.md`, `agents/skeptical-auditor.md` — the checkers
