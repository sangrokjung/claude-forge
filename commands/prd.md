---
description: Crystallize vague ideas into structured requirements before planning.
allowed-tools: Read, Write, Edit, Glob, Grep
argument-hint: "<idea/request> [--update] [--depth lite|standard|full]"
---

# PRD Command

Crystallize user ideas/requests into structured requirements. Use this **before** `/plan` when the request is vague, has multiple interpretations, or lacks clear acceptance criteria.

## Core Principles

1. **This is a conversation, not document generation.** Extract the user's intent through questions.
2. **Don't implement until crystallized.** Readiness Gate must pass before PRD is finalized.
3. **Don't resolve ambiguity with code.** Words like "properly", "well", "something like" must be eliminated before implementation.

## Absolute Rules
- Never generate or modify code
- Never fill in answers the user hasn't provided
- Never suggest next steps until Readiness Gate passes

---

## Procedure

### Step 1: Intent Discovery

Parse $ARGUMENTS and conversation context to understand the user's request.

**Idea-stage signals** — if detected, start probing instead of jumping to implementation:
- Abstract outcomes ("make it better", "clean up", "something like")
- No specific files/functions/screens mentioned
- Multiple directions mentioned simultaneously

**Scope Guard**: If the request contains multiple independent subsystems (e.g., "build chat + file storage + payments + analytics dashboard"), suggest decomposition before deep-diving:
- "This request contains N independent subsystems. I recommend separate PRDs for each."
- Start intent discovery with the first sub-project.

### Step 2: Structured Probing

Probe along 5 axes. **Ask one question at a time.** Previous answers shape the next question — bundling produces shallow answers. Prefer multiple-choice (A/B/C) over open-ended.

#### Axis 1: Problem
- "What's painful about the current situation?"
- "How often does this problem occur?"
- "Can you describe a specific scenario where this happens?"

#### Axis 2: Expected Outcome
- "What should it look like when done?"
- "What action will users be able to take?"
- "How will you know this succeeded?"

#### Axis 3: Boundaries
- "What must be included this time?"
- "What can be left out?"
- "Between X and Y, where's the boundary?"

#### Axis 4: Constraints
- "Any technical constraints?" (platform, compatibility, performance)
- "Any time/budget constraints?"
- "What existing systems must this integrate with?"
- If codebase exists: explore existing patterns first (Glob/Grep). Follow existing patterns by default.

#### Axis 5: Priority
- "Which feature must work first?"
- "If you split MVP vs later, what's in MVP?"
- "When trade-offs arise, what wins?" (speed vs completeness, features vs stability)

### Step 3: Depth Selection

| Depth | Condition | Output |
|-------|-----------|--------|
| **Lite** | Request is 1-2 sentences, outcome clear, no intent gap | Inline 3 items (goal + AC + exclusions). No file created |
| **Standard** | Scope/boundary setting needed, 2+ Q&A exchanges | `docs/plans/prd-{name}.md` |
| **Full** | Multiple stakeholders, non-functional requirements matter, L/XL estimate | Standard + scenarios + non-functional requirements |

### Step 4: Draft PRD

#### Lite Structure (inline)
```
**PRD (Lite)**: [name]
- Goal: [1 sentence]
- Acceptance Criteria: [1-3 items]
- Exclusions: [0-2 items]
```

#### Standard Structure
```markdown
# PRD: [name]

## Problem Definition
Why this work is needed. Current pain/gap. (1-2 sentences)

## Goal
Define completion state in one sentence. Must be observable.

## Acceptance Criteria
- [ ] (observable/measurable condition 1)
- [ ] (observable/measurable condition 2)
- [ ] (observable/measurable condition 3)

## Scope
### In Scope
- (what to implement — be specific)
### Out of Scope
- (what to exclude and why)

## Constraints
- (technical/time/compatibility constraints)

## Change Log
- Created: [date]
```

#### Full Structure (adds to Standard)
```markdown
## User Scenarios
1. [Persona] in [situation] does [action] and expects [result].

## Non-Functional Requirements
- Performance: (response time, throughput)
- Accessibility: (if applicable)
- Compatibility: (browsers, devices, runtime)

## Priority
| Item | Priority | Rationale |
|------|----------|-----------|
| ... | Must | ... |
| ... | Should | ... |
| ... | Could | ... |
```

### Step 5: Readiness Gate

Self-verify the draft against this checklist. **All items must pass for PRD to be finalized.**

```
## Readiness Checklist
- [ ] Goal is stated as an observable state?
      ("improve" X → "when X happens, Y is displayed" O)
- [ ] All acceptance criteria are testable/observable?
      ("faster" X → "response time under 500ms" O)
- [ ] No ambiguous items in scope inclusions/exclusions?
      ("related features" X → "dark mode toggle on settings page" O)
- [ ] No vague expressions remaining?
      ("properly", "well", "something like", "etc." X)
- [ ] No unconfirmed assumptions?
```

**On failure:**
- Show failed items to user
- Ask follow-up questions to clarify
- Update PRD and re-verify
- Repeat until gate passes

**On pass:**
- Finalize and report to user
- Save Standard/Full to `docs/plans/prd-{name}.md`
- Suggest next step: "PRD finalized. Use `/plan` to create an implementation plan."

---

## Special Modes

### `/prd --update`
Modify existing PRD. Record date and reason in change log.

Downstream invalidation policy:
| Downstream State | Action on PRD Change |
|------------------|---------------------|
| research/plan not created | Update PRD only |
| research exists, plan not created | Warn: "research.md based on old PRD. Re-run /explore recommended" |
| plan exists, implement not started | Warn + mark PRD reference mismatch in plan.md |
| implement in progress/done | Stop + report (same as master plan change policy) |

### Skip Conditions
Skip `/prd` and go directly to `/plan` when:
- Request specifies exact files/functions with clear expected outcome
- Bug fix with clear reproduction steps
- Mechanical tasks (dependency updates, etc.)
- User explicitly says "skip PRD"

---

## Anti-Patterns

1. **One question at a time**: Previous answers determine next question direction. Bundling 2-3 produces shallow answers.
2. **No leading questions**: Not "This should be A, right?" but "Between A and B, which fits?"
3. **No guess-filling**: Never complete areas the user hasn't answered.
4. **No excessive formality**: Don't force Full format on Lite targets.
5. **No premature implementation hints**: Before gate passes, don't say "We could use React for this".

$ARGUMENTS
