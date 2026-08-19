---
name: review-loop
description: Run the adversarial verification loop — implement, then hand the change to a fresh checker that did not write it, fix what it finds, and re-dispatch until APPROVE. Use before claiming any behavioural change is done, and on requests like "review loop", "adversarial review", "independent review", "get this verified", "is this actually done", "maker checker", "second pair of eyes on this change". Not for prose, docs or typo edits.
---

# review-loop — the independent adversarial loop

> Nobody grades their own exam. The maker implements, a separate fresh checker tries to break the
> claim, and the two alternate until the checker approves the code as it stands right now.

## When this applies

Any change to behaviour: executable code, shell/Python/JS/TS/SQL, CI/CD, hooks, commands, agent
and skill definitions, runtime prompts, and configuration that changes what the system does.

Exempt: prose documentation, marketing copy, typos, and formatting that cannot change behaviour.
When a documentation-only change also touches something a runtime reads, it is behavioural. If you
are unsure which side a change falls on, treat it as behavioural.

File count and diff size are not exemptions. A one-line change to an authorization check is
behavioural; a 900-line documentation reflow is not.

| Risk | Lanes required |
|---|---|
| Ordinary behavioural change | 1 independent checker |
| Auth, authorization, payments, access-control rules, secrets, destructive data changes, irreversible deploys | 2 lanes, run by different checkers: correctness plus the risk-specific angle (runtime security, or rollback) |

## The loop

```text
maker implements → targeted test / real-surface QA → fresh checker
     ↑                                                    │
     └────────── REQUEST_CHANGES ← findings ──────────────┘
                                                          │
                                          APPROVE on current code → done
```

There are exactly three verdicts: `APPROVE`, `REQUEST_CHANGES`, `UNVERIFIED`.

- **APPROVE** is a completion candidate only when it was issued against the revision that is
  checked out now, with evidence produced from that same revision.
- **REQUEST_CHANGES** means the maker fixes the findings surgically, re-runs the tests, and calls
  a fresh checker again. Fixing more than the findings restarts the argument.
- **UNVERIFIED** means no judgement was reached: the checker never ran, returned empty, timed out,
  errored, was rate-limited, returned a malformed envelope, or reviewed a state that has since
  moved. It is not a pass. Retry with a different checker, runtime, or strategy.

If a checker modifies the source, it has joined the maker set and its verdict is void. A past maker
can never be that change's checker.

## Running it

1. **Implement.** Keep the change inside the scope you declared. Unrelated cleanup that arrives in
   the same diff will be reviewed as part of it.

2. **Produce evidence before dispatch.** Run the targeted tests and, when the change has a surface a
   person uses, exercise that surface the way they would. Record the exact commands and their exit
   status. Evidence from before your last edit is stale.

3. **Dispatch a fresh checker.** Use the Task/Agent tool to spawn `adversarial-reviewer` in its own
   context, or a general-purpose agent given that agent's contract. Hand it:
   - the goal and acceptance criteria in one paragraph,
   - the scope (paths, or the diff range),
   - the commands you ran and what they returned,
   - the revision under review (`git rev-parse HEAD`).

   Do not hand it your conclusion. "I verified this works" is the claim under test, not context.

4. **Read the verdict, not the tone.** A checker that praises the change but lists a HIGH finding
   has returned REQUEST_CHANGES. A checker that died mid-run has returned UNVERIFIED, however
   encouraging its last message was.

5. **Fix and re-dispatch.** Every round gets a checker with a fresh context. Reusing the previous
   checker means asking someone to re-read their own conclusion.

6. **Stop when a current APPROVE exists** for the code as it stands, backed by evidence from that
   same revision.

## Re-verification etiquette

When you come back for round N+1, say so plainly:

- state what changed since the last round, in one or two lines, and name the finding each edit
  addresses;
- ask the checker to re-reproduce the original defect, not to take your word that it is gone;
- explicitly invite it to attack the fix itself. Fixes introduce their own defects, and a fix
  written under review pressure is exactly where a second one hides.

Both of the defects worked through in `docs/VERIFICATION-LOOP.md` were found this way: the first
review broke the guard, and the review of the *fix* broke the fix.

## When rounds stop converging

Three rounds on the same strategy is not a reason to stop, and it is not a reason to keep going
unchanged. Switch strategy: a different reproduction, a narrower test, a different checker or
runtime, or a re-plan of the approach. See `references/convergence-detection.md`.

Escalate to the human when the same finding comes back REQUEST_CHANGES twice in a row: two failed
attempts at one defect means the diagnosis is wrong, and a third attempt usually makes it worse.
Report the finding, both attempted fixes, and the reproduction. See `rules/adversarial-review.md`.

## Never report success when

- the reviewed revision is not the revision that is checked out now;
- there is no successful evidence from after the last edit;
- the checker was the maker, or a fork of the maker's context;
- a required lane is missing;
- the checker modified code, returned an empty or malformed verdict, or timed out;
- you are reusing an APPROVE from a different change or a different session.

In every one of those cases the honest report is what is missing, not "done".
