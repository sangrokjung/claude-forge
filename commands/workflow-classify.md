---
description: Classify task size (S/M/L/XL) and recommend the appropriate workflow pipeline.
allowed-tools: Read, Glob, Grep
---

# Workflow Classify Command

Classify task size and recommend the appropriate pipeline. Use this **before starting work** to avoid over-engineering small tasks or under-preparing large ones.

## Classification Criteria

| Size | Criteria | Pipeline |
|------|----------|----------|
| **S** | Single file, no logic change | Implement directly → `/quick-commit` |
| **M** | 2-5 files, within existing patterns | `/plan` → `/tdd` → `/handoff-verify` → `/commit-push-pr` |
| **L** | 5+ files or new patterns introduced | Full pipeline with phased implementation |
| **XL** | Data model, infrastructure, or security changes | Full pipeline + security review |

## Pipelines by Size

### S — Direct Implementation
```
(implement) → /quick-commit
```

### M — Standard Pipeline
```
/plan → /tdd → /code-review → /handoff-verify → /commit-push-pr
```
- Use `/auto` to run this automatically

### L — Phased Pipeline
```
/plan (master) → /plan-review → (human review)
  → [Per Phase]
    Phase N: /explore → /plan → /tdd → /code-review
  → /handoff-verify
  → /commit-push-pr
```
- Each Phase should be M-sized (5-15 files max)
- One session = one Phase (prevent context exhaustion)
- Phase failure: manual rollback to Phase branch

### XL — Phased Pipeline + Security
```
(same as L, plus:)
  → /security-review (CWE + STRIDE, once after all phases)
  → /handoff-verify
  → /commit-push-pr
```

## Sub-Phase Splitting (L/XL)

The key to L/XL tasks is **splitting each Phase to M-size**.

| Principle | Description |
|-----------|-------------|
| **M-size target** | 5-15 changed/new files per sub-Phase. Exceeding this triggers further splitting |
| **Naming** | `Phase N-A`, `N-B`, `N-C` (parent Phase number + alpha suffix) |
| **One-session completion** | Each sub-Phase must complete research→plan→implement→verify in a single session |
| **Maximize independence** | Minimize dependencies between sub-Phases to enable parallel work |
| **Explicit merge points** | Clearly define integration Phases where parallel work converges |

Split triggers:
- Impact analysis shows 15+ files → must split
- Changes span different layers (types, logic, UI, integration) → consider layer-based split
- 3+ new modules can be implemented independently → separate sub-Phases

## Escalation Rules (any YES → upgrade one level)

1. Does the change touch implicit system contracts?
2. Can failure NOT be rolled back with simple `git reset`? → auto XL
3. Does it affect user data or auth/authorization? → auto XL

## Procedure (Graduated Observation)

### Phase 0: PRD Check
Search `docs/plans/` for related `prd-*.md`.
- If PRD exists: use its scope and criteria as classification input
- If no PRD: proceed with $ARGUMENTS

### Phase 1: Quick Triage
1. Analyze $ARGUMENTS (and PRD scope if available)
2. Pre-scan affected files with grep/glob
3. Assess confidence:
   - File count ≤1, pattern clear → **HIGH** → classify as S immediately
   - File count ≥6 or security/DB/infra keywords → **HIGH** → classify as L/XL immediately
   - Any LOW confidence condition below → proceed to Phase 2

### LOW Confidence Conditions
If any of these are true, run Phase 2:
1. Grep hits span 3+ different domain directories
2. Target identifier is imported/used in 2+ files
3. User request doesn't specify exact files/functions
4. Estimated file impact range has 2x uncertainty (e.g., 3-8 files)
5. Changes involve hooks/settings/agents/pipeline files

### Phase 2: Targeted Probe (conditional)
Read up to **3 key files** to check:
- Import/export relationships (shared scope, consumer count)
- Whether the change target is an interface/contract vs internal implementation
- Do NOT analyze logic (that's `/explore`'s job)

### Phase 3: Final Classification
1. Classify based on Phase 1 or Phase 2 results
2. **If Phase 2 is still uncertain, upgrade one level** (under-classification costs more than over-classification)
3. Report in this format:

```
## Classification Result
- **Task**: (description)
- **PRD**: (path or "none")
- **Size**: S / M / L / XL
- **Rationale**: (why this size)
- **Estimated files**: N
- **Key files checked**: (Phase 2 only) file1 (exported N places), file2 (integration)
- **Escalation**: (if applied, which rule triggered it)
- **Recommended next step**: (next command to run)
```

Do not implement. Classification and reporting only.

$ARGUMENTS
