---
name: systematic-debugging
description: |
  Structured debugging methodology — use before proposing fixes for any error or failure.
  Covers: code bugs, build errors, deploy failures, config conflicts, dependency issues, infra problems.
  Also use when previous fix attempts failed or root cause is unclear.
---

# Systematic Debugging

## Overview

Guessing fixes wastes time and creates new bugs. Quick patches hide root problems.

**Core principle: Never fix before finding the root cause. Symptom fixing is failure.**

## Iron Law

```
Never propose a fix without root cause investigation.
```

Phase 0 or Phase 1 must be completed before any fix is proposed.
Phase 0 fixes are ONLY allowed when ALL of these are true:
- External research found an official solution or known issue for this exact error
- Change is single file, single point (config value, import, typo)
- No logic changes

## When to Use

**All technical problems:**
- Test failures, build errors, deploy errors
- Config conflicts, dependency issues
- Infrastructure/environment problems
- Unexpected behavior, performance issues

**Especially when:**
- Under time pressure (urgency breeds guessing)
- "Let me just quickly fix this" comes to mind
- Multiple fix attempts have already been tried
- Previous fixes didn't work
- You don't fully understand the problem

## The Phases

Each Phase must complete before proceeding to the next.

### Phase 0: Quick Assessment

Run immediately when an error occurs. Before any fix attempt.

1. **Classify the error** — read the error message/symptoms:
   - Same code works in different environment? → Environment issue
   - After recent dependency/version change? → Dependency issue
   - Only fails in specific code path? → Code issue

2. **External research (exact match, 5 min max)** — check official docs and GitHub Issues for known issues. Don't rely on self-knowledge alone.
   - See: `references/external-research-guide.md`

3. **Branch decision**:
   - All Iron Law conditions met → Fix in Phase 0
   - Any condition unmet → Enter Phase 1 full process
   - **Phase 0 quick-fix fails**: Undo (git checkout/undo), enter Phase 1. This attempt counts in the fix counter.

### Phase 1: Root Cause Investigation

**Before any fix attempt:**

1. **Read the error carefully**
   - Don't skip errors/warnings
   - Read the entire stack trace
   - Record line numbers, file paths, error codes

2. **Reproduce consistently**
   - Get exact reproduction steps
   - Every time? If intermittent, collect more data

3. **Check recent changes**
   - git diff, recent commits
   - New dependencies, config changes
   - Environment differences (env vars, Node/runtime version, OS)

4. **Research external sources (deep read)**
   - Based on Phase 0 exact match results, investigate further
   - Read official docs for the failure mechanism
   - Check release notes for breaking changes
   - See: `references/external-research-guide.md`

5. **Collect evidence in multi-component systems**
   - Log data in/out at each component boundary
   - Run once to find where it breaks
   - Then deep-dive into that component

6. **Trace data flow**
   - Where does the wrong value originate?
   - Trace the call stack backwards to the source
   - See: `references/root-cause-tracing.md`

### Phase 2: Pattern Analysis

1. **Find similar working code** in the same codebase
2. **Compare with reference implementations** — read the full reference docs, don't skim
3. **Identify all differences** between working and broken — don't assume "that's irrelevant"
4. **Map dependencies** — what config, environment, other components are needed

### Phase 3: Hypothesis and Testing

**Before entering Phase 3:**
- Verify clean state (git status)
- If not clean: git stash or save checkpoint
- On hypothesis failure: rollback to safe point, try new hypothesis (no cumulative fixes)

1. **Form a single hypothesis**: "X is the root cause because Y" — specific, not vague
2. **Test minimally**: smallest change to verify the hypothesis. One variable at a time.
3. **Verify before proceeding**:
   - Success → Phase 4
   - Failure → **New hypothesis** (don't stack fixes on top of failed ones)

### Phase 4: Implementation

1. **Write a failing test** — simplest reproduction, automated if possible, before fixing
2. **Apply a single fix** — only the identified root cause, one change at a time, no "while I'm at it"
3. **Verify the fix** — test passes? No other tests broken? Problem actually resolved?
4. **If fix doesn't work**:
   - How many fix attempts so far?
   - Under 3: return to Phase 1 with new information
   - **3 or more: proceed to Phase 4.5**

### Phase 4.5: Architecture Question

**Pattern of 3+ failed fixes:**
- Each fix reveals new problems elsewhere
- Fix requires "major refactoring"
- Each fix creates symptoms in other places

**Stop immediately and ask fundamental questions:**
- Is this pattern itself sound?
- Are we clinging to it out of inertia?
- Should we refactor the architecture instead of fixing symptoms?

**Report to user and discuss before any more fix attempts.**

## Red Flags — If you think this, STOP

- "Let me quickly fix it and investigate later"
- "Let me try changing X and see if it works"
- "Let me bundle multiple changes and test once"
- "Skip tests, just check manually"
- "It's probably X, let me fix it"
- "I don't fully understand but this might work"
- "Let me just try one more fix" (after 2+ attempts)
- "I don't need to check external docs for this one"
- "This is definitely a code issue" (without checking environment)

**Any of the above: STOP. Return to Phase 0/1.**
**3+ fix failures: Architecture Question (Phase 4.5)**

## Common Rationalizations

| Excuse | Reality |
|--------|---------|
| "Simple problem, don't need the process" | Simple problems have root causes too. The process is fast for simple bugs. |
| "Too urgent for process" | Systematic debugging is **faster** than guessing. |
| "Let me try this first, then investigate" | First fix sets the pattern. Start right. |
| "I'll write tests after fixing" | Fixes without tests don't last. Test first. |
| "Bundle changes to save time" | Can't tell what worked. Creates new bugs. |
| "Docs are too long, I'll wing it" | Partial understanding = guaranteed bugs. Read it all. |
| "I can see the problem, just fix it" | Seeing symptoms ≠ understanding root cause. |
| "One more fix" (2+ failures) | 3+ failures = architecture problem. Ask, don't fix. |
| "I know this error, no need to check docs" | LLM confidence ≠ accuracy. Verify externally. |

## Supporting Techniques

See references in this directory:
- **`references/external-research-guide.md`** — External docs/GitHub Issues lookup procedure
- **`references/root-cause-tracing.md`** — Call stack backtracing to find bug origins

## Quick Reference

| Phase | Key Activity | Success Criteria |
|-------|-------------|-----------------|
| **0. Quick Assessment** | Error classification, external research (exact match) | Error type classified + 1+ external search done |
| **1. Root Cause** | Read errors, reproduce, check changes, deep research | Understand what breaks and why |
| **2. Pattern** | Find working similar code, compare | Differences identified |
| **3. Hypothesis** | Single hypothesis, minimal test | Confirmed or new hypothesis |
| **4. Implementation** | Write test, fix, verify | Bug fixed, tests pass |
| **4.5. Architecture** | Stop after 3 failures, report | Architecture review decision |
