# Golden Principles

> 11 core principles for writing clean, maintainable code.

## 1. Immutability

**Why?** Mutation is a breeding ground for bugs. It's impossible to track where a value changed.

**How?** Use spread operators to create new objects. Never modify the original.

## 2. Secrets in Environment Variables

Never hardcode secrets. Use `process.env` only; throw immediately if unset.

## 3. Test First (TDD)

**Why?** Writing tests after implementation leads to "tests that only pass." You miss failure cases.

**How?** RED (failing test) -> GREEN (minimal implementation) -> IMPROVE (refactoring). 80%+ coverage.

## 4. Conclusion First, Reasoning Second

Lead with the conclusion in the first sentence. Add "because..." after.

## 5. Small Files, Small Functions

File: 800 lines max. Function: 50 lines max. Nesting: 4 levels max. Split if exceeded.

## 6. Validate at System Boundaries

Trust internal code, but validate user input and external API responses (e.g., zod schemas, parameterized queries).

## 7. Explain with Analogies

Everyday analogy first (1-2 sentences), then technical explanation.

## 8. Context 50% Rule

Complete work within 50% of the context window. Split large tasks into new sessions.

## 9. HARD-GATE: No Coding Without Design

Run `/plan` first if any of these apply: new feature (3+ files), architecture change, API endpoint change, DB schema change. No code until the user approves the plan. Exception: simple fixes (1-2 files, typo/bug patches).

## 10. Evidence-Based Completion

**Why?** "It's done" without evidence is a lie. LLMs tend to declare completion without execution.

**How?** Before claiming completion:
1. Show test results (pass/fail count, coverage)
2. Confirm build success by running it
3. Check requirements against a checklist with evidence

**Banned**: "This should work", "No issues expected" — speculative completion claims
**Required**: "12 tests passed", "Build success (0 errors)" — execution evidence

## 11. SDD Review Enforcement

When using subagent-driven development: spec compliance first, issues found = not done, "close enough" doesn't count.

---

## Anti-Rationalization (These excuses don't work)

| Principle | Excuse | Reality |
|-----------|--------|---------|
| TDD | "Too simple to need tests" | Simple code breaks too. Tests take 30 seconds |
| TDD | "I'll add tests later" | Tests written later only cover happy paths |
| TDD | "TDD is slow" | TDD is faster than debugging |
| Immutability | "Need mutation for performance" | Only after profiling proves it |
| Secrets | "It's just the test environment" | Test secrets in commits are permanently exposed |
| File size | "It's small enough" | Review for splitting at 400+ lines |
| Boundary | "Internal function, no validation needed" | System boundary decisions belong to the designer |
| Analogy | "Unnecessary for technical audiences" | Project rule. No exceptions |
| Conclusion | "Hard to conclude without context" | One-line conclusion first, context after |
| Context | "Still have room left" | Over 50% = new session. No exceptions |
| HARD-GATE | "Quick fix, no plan needed" | 3+ files changed = plan first |
| Evidence | "It already works fine" | Claims without evidence are false. Show execution results |
| SDD | "Skip review, move to next task" | Unreviewed = incomplete. No exceptions |
| Ralph Loop | "Let me just try one more approach" | Stop. Plan first, then execute once |
| /simplify | "The complexity is necessary" | Run /simplify. If it finds reduction, it wasn't necessary |
