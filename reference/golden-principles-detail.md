# Golden Principles — Detail Reference

> Source: rules/golden-principles.md (core principles are there, details here)

## Anti-Rationalization Table

These excuses don't work:

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
| Surgical | "While I'm here, let me clean up" | Only change requested lines. Cleanup is a separate request |
| Simplicity | "Need abstraction for extensibility" | Only what's needed now. Abstract when repetition hits 3+ times |
