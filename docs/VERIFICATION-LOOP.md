# The verification loop, worked through

This document shows the adversarial loop doing its job on real changes in this repository, using
three defects it caught on 2026-08-18 in PR #58 and PR #61. Nothing here is hypothetical: every
command, number and error string below came from those reviews.

Read `rules/adversarial-review.md` for the rule, `skills/review-loop/SKILL.md` for the procedure,
and this file for what it actually feels like when it works.

## The shape

```text
maker implements → runs targeted evidence → fresh checker reproduces
     ↑                                              │
     └────────── REQUEST_CHANGES ← findings ────────┘
                                                    │
                                    APPROVE on current code → done
```

The checker did not write the change, does not see the reasoning that produced it, and is asked to
break the claim rather than to read it. That last part is what produced all three findings below.

## Round 1: a guard that could not catch its own regression

**The change.** This repository ships two installers, `install.sh` and `install.ps1`, which must
install the same set of directories. An earlier bug had let one directory silently disappear from
the Windows installer, so PR #58 added a CI step to keep them in parity.

The guard read the directory names and checked that each one appeared in `install.ps1`.

**What the maker believed.** The guard passes on the real files, so the parity check works.

**What the checker did.** Instead of reading the guard, it made the regression the guard exists to
catch: it copied `install.ps1`, removed `"scripts"` from the `$directories` array, and ran the guard
against that copy. The guard grepped the *whole file* for `"scripts"`, quotes included, and three
lines above the array sat a comment naming the same directories in quotes: *"Omitting `"scripts"` or
`"cc-chips-custom"` leaves ... missing on Windows"*. That comment, added in this very PR to warn
future editors, kept the check green while the installer no longer installed the directory:

```text
old guard on the sabotaged copy:  missing=0        <- false pass
```

A guard that passes on its own regression is worse than no guard, because it converts an absent
check into a green check.

Here is that verdict in full, in the `forge.review/v1` envelope that `agents/adversarial-reviewer.md`
emits:

```json
{
  "schema": "forge.review/v1",
  "verdict": "REQUEST_CHANGES",
  "task_ref": "PR #58 — installer parity guard (install.ps1 must ship every install.sh directory)",
  "change_ref": "eb0fd5a (PR #58 head at review time)",
  "findings": [
    {
      "severity": "HIGH",
      "location": ".github/workflows/validate.yml:241",
      "description": "The parity step greps the entire install.ps1 text for each directory name, not the $directories array. I removed \"scripts\" from the array on a copy, left the comment above it (which quotes \"scripts\" and \"cc-chips-custom\") in place, and the guard reported missing=0. The guard therefore passes on the exact regression it was added to catch, and the comment shipped in this same PR is what masks it.",
      "suggestion": "Parse the array rather than the file: extract $directories from install.ps1 through the PowerShell AST, and read install.sh's `for dir in ...; do` loop as the source of truth instead of hardcoding the list."
    }
  ],
  "evidence_checked": [
    "cp install.ps1 /tmp/sabotage.ps1 && removed \"scripts\" from $directories, comment left intact",
    "ran the PR's parity step against /tmp/sabotage.ps1 -> missing=0, step exit 0 (expected: failure)",
    "ran the PR's parity step against the real install.ps1 -> passes (so the green result proves nothing)"
  ],
  "summary": "The guard is string-matching the file, not the data structure, so any mention of a directory name anywhere in install.ps1 satisfies it. Reproduced a silent-omission regression that CI reports as green. Fix by parsing the array; the passing result on the real files does not distinguish a working guard from this one."
}
```

**The fix** (commit `58d9107`): read `install.sh`'s `for dir in ...; do` loop as the source of
truth, and extract `$directories` from `install.ps1` through the PowerShell AST, so comments and
unrelated string matches cannot affect the result. It also stopped hardcoding the list, which turned
"someone added a directory to `install.sh` only" from a silent drift into a CI failure.

## Round 2: the fix had the same class of hole, one level down

The maker re-dispatched with what changed and asked the checker to attack the fix itself. It did.

**The finding.** The AST guard looked up `$directories` and checked the **first** assignment it
found. PowerShell resolves the **last** assignment in a scope at runtime. So a file with a second
assignment would be validated on a value the installer never uses:

```text
second $directories assignment that drops "scripts":
  CI:       green
  runtime:  directory not installed
```

Same silent-omission shape as round 1, reached through a different door. Note also the asymmetry the
checker used to find it: the `install.sh` side of the step already required *exactly one* loop, while
the `install.ps1` side accepted "one or more" and then looked at the first.

**The fix** (commit `e8e62a6`): require exactly one `$directories` assignment, making both sides
symmetric.

```text
::error file=install.ps1::expected exactly one $directories assignment, found 2
```

## Round 3: APPROVE

Verified with pwsh 7.6.5: the real files pass with 8 of 8 directories matched, and both sabotaged
copies (the removed entry, and the second assignment) now fail. The claim was reproduced in both
directions, which is what an APPROVE requires: the guard fires when it should, and passes when it
should.

## The third defect: a dependency ceiling that pinned the past

Later the same day, the review of PR #61 read a dependency bound that had been written from memory:

```text
lxml>=5.2.2,<6
```

The floor was researched; the ceiling was assumed. The checker looked up the live index instead of
trusting the shape of the number. lxml 6.0.0 shipped 2025-06-26 and the current stable was 6.1.1, so
`<6` excluded the entire current major and resolved installs to 5.4.0, a release from 2025-04-23.
The PR's own description criticised `==` pins for causing staleness, and its new ceiling reproduced
that staleness by a different mechanism.

**The fix** (commit `09a1d9d`): `<7`, which is the correct bound because 7.0.0 exists only as alphas
and pip does not install those by default. All three bounds were then checked against live PyPI
rather than assumed, and a clean virtualenv was resolved to confirm it:

```text
python-docx>=1.1.2,<2    latest 1.2.0      included
lxml>=5.2.2,<7           latest 6.1.1      included
PyMuPDF>=1.24.3,<2       latest 1.28.2     included
```

The same review round also reversed a design decision: a proposed `Task` grant for `verify-agent`
was dropped, and the prose that motivated it was corrected instead. That is what kept this
repository at zero Task-holding agents.

## What the three have in common

None of them was a typo, and none would have been caught by a careful re-read.

1. **They were all invisible from the inside.** Each defect sat exactly where the author's attention
   had already been and had already been satisfied. The comment that masked the grep was written by
   the same person, in the same commit, as the guard it defeated.
2. **They were all caught by reproduction, not reading.** The checker built the failure case and ran
   it. "I read the guard and it looks correct" would have passed all three.
3. **Two of them were in a fix.** Round 2 existed only because round 1's fix was reviewed as
   adversarially as the original. This is why `skills/review-loop/SKILL.md` tells you to invite
   attack on the fix itself: code written under review pressure is where the next defect hides.

The cost was three review rounds across two PRs in one day. The alternative was a Windows installer
that silently skipped a directory while CI stayed green, plus a dependency resolution a year out of
date.

## Running it yourself

```text
1. Implement, then run the targeted evidence yourself. Record the commands and exit codes.
2. Dispatch adversarial-reviewer (Task/Agent tool) with: the goal, the scope, the commands you ran,
   and `git rev-parse HEAD`. Do not hand it your conclusion.
3. On REQUEST_CHANGES, fix exactly the findings, re-run the evidence, and dispatch a fresh checker.
   Tell it what changed and ask it to re-reproduce the original defect.
4. Stop on an APPROVE issued against the revision that is checked out now.
5. If the same finding comes back twice, stop looping and surface it to a human.
```

`UNVERIFIED` is not a pass, and a checker that timed out has told you nothing. See
`rules/adversarial-review.md`.
