# Verification — Detail Reference

> Source: rules/verification.md (core gate function and checklist are there, details here)

## Red Flags — Stop If You Think This

| Thought | Reality |
|---------|---------|
| "It probably works" | Run verification |
| "I'm confident" | Confidence is not evidence |
| "Just this once" | No exceptions |
| "Linter passed, so..." | Linter ≠ compiler ≠ tests |
| "The agent said it succeeded" | Verify independently |
| "It's a simple change, no need to verify" | Simple changes break too |
| "I already ran it earlier" | Earlier ≠ now. Run again |
| "Should", "probably", "seems to" | Probabilistic language is not evidence |
| "Great!", "Perfect!", "Done!" | Do not express satisfaction before verification |
| "Partial check is enough" | Partial proves nothing |

## Verification Patterns

### Tests

```
CORRECT: [run test command] → [output: 34/34 passed] → "All 34 tests passed"
WRONG:   "It should pass" / "Looks correct to me"
```

### Build

```
CORRECT: [run build] → [output: exit 0, 0 errors] → "Build succeeded"
WRONG:   "Linter passed, so build should work too"
```

### Requirements

```
CORRECT: Re-read plan → Create checklist → Verify each item → Report gaps or completion
WRONG:   "Tests pass, so the feature is done"
```

### Agent Delegation

```
CORRECT: Agent reports success → Check VCS diff → Verify changes → Report actual state
WRONG:   Trust agent report without independent verification
```

## The Bottom Line

There are no shortcuts to verification.

Run the command. Read the output. Then — and only then — state the result.

This is non-negotiable.
