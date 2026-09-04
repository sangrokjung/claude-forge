---
name: plan-review
description: |
  Expert panel reviews a plan from multiple perspectives and produces a consensus.
  Claude acts as lead/moderator — orchestrates the panel, synthesizes opinions, resolves conflicts.
  The lead does NOT participate as an expert — orchestration and judgment only.
---

# Plan Review

## Overview

An expert panel (2-4 members) reviews a plan.md from multiple independent perspectives,
then the lead synthesizes a consensus with concrete modification proposals.

## Parameters

| Input | Description |
|-------|-------------|
| `plan.md path` | Path to the plan to review |
| `--panel <path>` | Pre-configured expert-panel.md (auto-generates if not provided) |
| `--experts N` | Number of experts (default 3, passed to assemble-experts) |
| `--lite` | Lightweight mode: lead simulates each expert in single context (no Agent spawn) |

## Procedure

### Phase 1: Preparation

1. Extract plan.md path from $ARGUMENTS
   - No path → search `docs/plans/` for plan-*.md
   - Multiple candidates → show list, ask user to pick
   - Single candidate → confirm with user
2. Read plan.md
3. Check for existing panel:
   - `--panel` specified → Read that file
   - Not specified → search `docs/plans/expert-panel-*.md` matching topic
   - No match → proceed to Phase 2

### Phase 2: Panel Assembly (if needed)

Read `skills/assemble-experts/SKILL.md` and execute its Phase 1-4 logic directly.
Do NOT invoke `/assemble-experts` as a separate Skill call.

1. Classify domain from plan.md content
2. Design experts per assemble-experts logic
3. Save to `docs/plans/expert-panel-{topic}.md`
4. Get user approval on panel composition

**Do not proceed to Phase 3 without user approval.**

### Phase 3: Independent Analysis

#### Default Mode: Parallel Agent Spawn

Spawn each expert as a **parallel Agent** (opus model).

Show confirmation first:
```
Spawning N experts as opus Agents for parallel analysis. Proceed?
```

Each Agent receives:
```
You are [Role Name].

[Agent prompt from expert-panel.md]

Analyze the plan below and write your review in the specified output format.
Do not write code. Analysis and review only.

---
[Full plan.md content]
---
```

Spawn all 2-4 Agents in a **single message** (parallel, no dependencies).

#### `--lite` Mode: Lead Simulation

No Agent spawn. Lead (Claude) adopts each expert's perspective sequentially:
1. Read each expert's prompt from expert-panel.md
2. Analyze plan from that perspective, write review in output format
3. After all experts done, proceed to Phase 4

### Phase 4: Consensus Meeting (Lead Synthesis)

When all expert analyses arrive:

#### Step 1: Collect & Organize
Summarize each expert's results in a table:

| Item | Expert A | Expert B | Expert C |
|------|----------|----------|----------|
| Rating | APPROVE | CONCERN | BLOCK |
| Key concern | - | target unclear | legal risk |

#### Step 2: Identify Agreement vs Conflict
- **Consensus** (majority agrees): classified as confirmed
- **Majority opinion** (plurality but not majority): adopt with minority noted
- **Conflict** (evenly split): lead analyzes trade-offs and makes a judgment call

#### Step 3: Purpose Validation (Meta-check)
Synthesize experts' "Purpose Validation" sections:
1. **Problem definition**: Does the plan's goal section clearly state the pain/gap?
2. **Solution fitness**: Does the proposed change directly address the stated problem?
3. **Success criteria validity**: Can we observe whether the goal was achieved?

#### Step 4: Resolve Conflicts
For each conflict:
1. Define the conflict point precisely
2. Compare rationale and risks of each position
3. Judge which aligns with the plan's goals and constraints
4. State the judgment rationale explicitly

**If any BLOCK exists:**
- Review BLOCK reason with highest priority
- If valid → must address in modification proposal
- If excessive → downgrade to CONCERN with rationale, defer to user

#### Step 5: Write Consensus Document
Save to `docs/plans/review-consensus-{topic}.md`:

```markdown
## Plan Review Consensus

### Panel
| # | Role | Rating |
|---|------|--------|
| 1 | [role] | APPROVE / CONCERN / BLOCK |

### Agreed Items (all experts)
1. [agreed point]

### Recommended Modifications
| # | Change | Rationale | Proposed by | Agreed by |
|---|--------|-----------|-------------|-----------|
| 1 | [specific change] | [reason] | Expert B | A,C agree |

### Conflict Resolution (Lead Judgment)
| # | Issue | Adopted | Rationale |
|---|-------|---------|-----------|
| 1 | [issue] | Expert A's position | [judgment basis] |

### Minority Opinions (Recorded)
- Expert D: [dissenting view summary]

### Purpose Validation (Lead Meta-check)
- Problem definition: [adequate / needs revision — rationale]
- Solution fitness: [adequate / needs revision — rationale]
- Success criteria: [adequate / needs revision — rationale]

### Proposed plan.md Changes
(Specific modifications in diff style)

#### Change 1: [section]
- **Current**: [existing text]
- **Proposed**: [new text]
- **Based on**: Recommendation #N
```

### Phase 5: User Decision & Application

1. Present full consensus to user
2. Offer choices:
   - **Accept all**: Apply all proposed changes to plan.md
   - **Partial accept**: Select specific changes
   - **Reject**: Keep original plan unchanged
   - **Re-review**: Request additional analysis on specific points (max 2 rounds)
3. Apply approved changes via Edit tool
4. Report completion:

```
Plan review complete. Changes applied to plan.md.
Consensus: docs/plans/review-consensus-{slug}.md

Next steps:
- Review the updated plan, then proceed with /tdd or /auto.
- Run /plan-review again if further review is needed.
```

## Constraints

- Lead does NOT participate as an expert. Orchestration only.
- Expert Agents do NOT modify plan.md. Analysis only.
- Plan.md changes require user approval. Lead applies after approval.
- Expert opinions outside plan scope → classified as "side note", not included in modifications.
- BLOCK reasons must be addressed. Never ignored. Always reviewed with explicit rationale.

## Error Handling

| Situation | Response |
|-----------|----------|
| plan.md not found | Ask user for path |
| 1 Agent spawn fails | Proceed without that expert, notify user |
| 2+ Agent failures (< 2 remaining) | Abort review, offer panel rebuild or --lite |
| Expert output doesn't match format | Lead extracts key content and reorganizes |
| All APPROVE (no changes) | Report "All approved. No changes needed." and finish |
| All BLOCK | Recommend plan rewrite to user |

$ARGUMENTS
