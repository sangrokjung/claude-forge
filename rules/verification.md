# Verification Before Completion

> Extends [Golden Principle #10: Evidence-Based Completion](golden-principles.md#10-evidence-based-completion).
> Think of it like a courtroom: "it probably works" is as valid as "probably innocent" — not at all. Evidence first, claims second.

## The Iron Law

```
NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE
```

If you did not run a verification command **in this message**, you cannot claim it passed. Previous runs do not count — the code may have changed since then.

## The Gate Function

Before making any claim about success, completion, or satisfaction:

```
1. IDENTIFY  — What command proves this claim?
2. RUN       — Execute the full command (fresh, complete)
3. READ      — Read the entire output, check exit code, count failures
4. VERIFY    — Does the output confirm the claim?
                No  → Report actual state with evidence
                Yes → Proceed to claim with evidence
5. CLAIM     — Only now state the result

Skipping any step = not verification, just guessing.
```

## Verification Checklist

| Claim | Required Evidence | Insufficient Evidence |
|-------|------------------|----------------------|
| Tests pass | Test command output: 0 failures | Previous run, "should pass" |
| Linter clean | Linter output: 0 errors | Partial check, assumption |
| Build succeeds | Build command: exit 0 | "Linter passed so build will too" |
| Bug fixed | Regression test: passes | "Code changed, assume fixed" |
| Regression test works | Red-Green cycle verified | Single pass without failure check |
| Agent task complete | VCS diff confirms changes | Agent self-reported "success" |
| Requirements met | Line-by-line checklist verified | "Tests pass so requirements met" |

## Red-Green Verification (TDD)

For regression tests and bug fixes, a single pass is not enough:

```
1. Write test       → Run → PASS (confirms test works)
2. Revert the fix   → Run → FAIL (confirms test catches the bug)
3. Restore the fix  → Run → PASS (confirms fix resolves the bug)
```

If step 2 does not fail, the test is not actually testing the fix.

## When to Apply

**Always**, before:
- Any claim of success or completion
- Creating commits or pull requests
- Marking tasks as complete
- Moving to the next task

> Detail: reference/verification-detail.md § Red Flags, Verification Patterns, and Examples
