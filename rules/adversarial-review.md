---
name: adversarial-review
load: always
audience: team
sensitivity: L1
category: verification
critical: true
description: Behavioural changes are done when an independent checker approves them, not when the author believes they work — the three verdicts, what checker independence means, and when to stop and ask a human.
---

# Adversarial Review (CRITICAL)

> Analogy: nobody grades their own exam. The author of a change has already convinced themselves;
> that is why they shipped it. The only reading that adds information comes from someone who did
> not write it and is trying to prove it wrong.

## When the loop is mandatory

Every change to behaviour goes through the loop in `skills/review-loop/SKILL.md` before it is
called done: executable code, shell/Python/JS/TS/SQL, CI/CD, hooks, commands, agent and skill
definitions, runtime prompts, and configuration that changes what the system does.

Prose docs, copy and typos are exempt. Diff size is not an exemption in either direction: a one-line
change to an authorization check is behavioural, and a large documentation reflow is not. When a
change is ambiguous, treat it as behavioural.

Ordinary changes need one independent checker. Auth, authorization, payments, access-control rules,
secrets, destructive data changes and irreversible deploys need two lanes run by different checkers:
correctness, plus the risk-specific angle (runtime security, or rollback).

## The three verdicts

There are exactly three. A fourth phrasing ("approve with comments", "looks good, but") is a
category error: decide which of the three it is.

| Verdict | What it means | What it obligates |
|---|---|---|
| `APPROVE` | The checker tried to break the claim against the current revision and failed, with no CRITICAL or HIGH finding | Completion is allowed, for **this** revision only. Any further edit voids it |
| `REQUEST_CHANGES` | At least one CRITICAL or HIGH finding, reproduced | The maker fixes exactly those findings, re-runs the evidence, and dispatches a **fresh** checker. Not the same one |
| `UNVERIFIED` | No judgement was reached: the checker never ran, returned empty or malformed output, timed out, was rate-limited, or reviewed a revision that has since moved | Retry with a different checker, runtime or strategy. Never convert it to a pass |

### Audit statuses are not verdicts

`skeptical-auditor` returns `PASS`, `FAIL` or `UNCERTAIN`. Those are audit statuses about a claim
another agent already made, not loop verdicts, and the two vocabularies must not be mixed in the
same sentence. When an audit feeds a completion decision, map it:

| Audit status | Loop verdict | Why |
|---|---|---|
| `PASS` | `APPROVE` | The claimed steps were re-run and actually pass |
| `FAIL` | `REQUEST_CHANGES` | A blockable finding was reproduced |
| `UNCERTAIN` | `UNVERIFIED` | No judgement was reached: turn budget exhausted, the revision moved, or the evidence could not be re-run |

`UNCERTAIN` maps to `UNVERIFIED` and never to `REQUEST_CHANGES`. "I could not judge this" is a
different statement from "this is broken", and collapsing the two sends the maker off to fix a
defect nobody has demonstrated.

## Reviewer death is not approval

A checker that crashes, times out, hits a rate limit, or returns nothing has told you nothing. The
absence of findings is not the absence of defects. Treat every one of these as `UNVERIFIED` and
dispatch again; if no checker can be reached at all, report the change as unverified and stop.
Self-review does not substitute for a dead reviewer. That substitution is the failure this rule
exists to prevent, because it feels like diligence while removing the only independent signal.

## What makes a checker independent

All four must hold:

1. **Fresh context.** The checker starts from the change and the goal, not from the conversation
   that produced them. It has not seen the reasoning that justified the code.
2. **Did not author the change.** Not this revision, and not an earlier revision of the same work.
   A past maker is permanently disqualified as that change's checker.
3. **Not a fork of the maker.** A continuation, fork or resumption of the authoring session carries
   the author's assumptions, which is precisely what needs testing.
4. **Read-only.** If the checker edits the source, it has joined the maker set and its verdict is
   void. Findings go back to the maker.

A checker that reads the maker's summary and agrees with it has verified the summary, not the code.
Independence is about what the checker reproduces, not about which model ran it.

These four conditions are enforced by convention, not by machinery: nothing in this repository
physically prevents a maker from reviewing its own change, and a self-review returns an envelope
that looks exactly like a real one. The loop is only as good as the dispatcher honouring condition 2.
That is why the honest failure report is `UNVERIFIED` rather than a verdict you were in no position
to issue.

## Escalate to a human after two

When the same finding comes back `REQUEST_CHANGES` twice in a row, stop. Two failed fixes on one
defect mean the diagnosis is wrong, and the third attempt usually enlarges the damage rather than
the understanding.

Surface to the human: the finding, both attempted fixes, the reproduction command and its output,
and what you now believe is actually wrong. Do not keep looping, do not lower the severity, and do
not restate the goal so the current code satisfies it.

## Related

- `skills/review-loop/SKILL.md` — the loop itself, dispatch instructions, re-verification etiquette
- `agents/adversarial-reviewer.md` — the checker and the `forge.review/v1` verdict envelope
- `agents/skeptical-auditor.md` — re-verification after a self-verifying agent claims a pass
- `docs/VERIFICATION-LOOP.md` — a worked example, with three real defects this loop caught
- `rules/verification.md` — evidence before completion claims (this rule adds: whose evidence)
