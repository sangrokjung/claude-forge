---
name: assemble-experts
description: |
  Dynamically assemble a 2-4 person expert panel for any domain.
  Works with /plan-review or standalone. Covers dev, marketing, finance, legal, business, and more.
---

# Assemble Experts

## Overview

Analyze a topic to design a panel of 2-4 experts with non-overlapping perspectives.
The lead (Claude) executes this directly — no subagents used for panel assembly.

## Parameters

| Input | Description |
|-------|-------------|
| `topic` | Topic that needs an expert team (natural language) |
| `--experts N` | Number of experts (default 3, range 2-4) |
| `--domain <d>` | Domain hint (override auto-detection) |
| `--for-plan <path>` | Plan path → auto-extract topic from plan content |

## Procedure

### Phase 1: Domain Classification

Parse $ARGUMENTS. Extract flags first, remaining text = topic.

| Domain | Keywords/Signals |
|--------|-----------------|
| dev | code, API, DB, infra, refactoring, deploy, test |
| marketing | marketing, branding, GTM, campaign, SEO, ads |
| finance | financial, investment, revenue, cost, ROI |
| legal | law, contract, regulation, IP, license |
| business | business model, market entry, strategy, competition |
| mixed | 2+ domains → primary gets ceil(N/2), secondary gets remainder |

**Dev domain detected**: Reuse existing agents from `agents/` (architect, security-reviewer, code-reviewer).
Record references in expert-panel instead of creating new profiles.
For dev + other domain mix: reuse agents for dev side, create new profiles for the rest.

### Phase 2: Expert Design

Design experts with **non-overlapping perspectives** per domain.

Each expert needs:
1. **Role name** (English)
2. **Perspective**: Unique angle this expert brings
3. **Expertise areas**: 3-5 specific knowledge domains
4. **Analysis framework**: Methods/tools this expert uses
5. **Key questions**: 3-5 things this expert always checks
6. **Risk detection points**: Risks this perspective must catch

**Perspective distribution principles:**
- Strategy vs Execution
- Internal (org/resources) vs External (market/competition)
- Offense (opportunity/growth) vs Defense (risk/protection)
- Quantitative (data/metrics) vs Qualitative (experience/intuition)
- Purpose (WHY) vs Means (HOW) — at least 1 expert must cover "Is this plan solving the right problem?"

For 4 experts: distribute across at least 3 axes, WHY axis must be covered by at least 1.

### Phase 3: Domain Reference Panels

#### Dev Domain
Reuse existing forge agents. Example panel:
| # | Role | Source | Perspective |
|---|------|--------|-------------|
| 1 | Systems Architect | `agents/systems-architect.md` | Coupling, extensibility, interfaces |
| 2 | Workflow Engineer | `agents/workflow-engineer.md` | State transitions, failure modes |
| 3 | DX Engineer | `agents/dx-engineer.md` | Usability, cognitive load |

#### Business Domain
| # | Role | Perspective | Framework |
|---|------|-------------|-----------|
| 1 | Business Strategist | Business model, competitive strategy | Porter's 5 Forces, Canvas, SWOT |
| 2 | Market Analyst | Market size, trends, timing | TAM/SAM/SOM, Trend Analysis |
| 3 | Financial Modeler | Unit economics, growth scenarios | Unit Economics, Cohort, Projection |
| 4 | Operations Expert | Execution feasibility, resources | OKR, Gantt, Resource Planning |

(Additional reference panels for marketing, finance, legal, investment, HR, industry domains follow similar patterns — adapt based on the specific topic.)

### Phase 4: Generate Panel Document

Save to `docs/plans/expert-panel-{topic-slug}.md`:

```markdown
# Expert Panel: [topic]

- **Schema**: v1
- **Generated**: [date]
- **Domain**: [classified domain]
- **Experts**: [N]
- **Status**: ready

---

## Expert 1: [Role Name]

**Profile-Type**: custom (or reuse-agent)
**Source**: (if reuse-agent: path to agent file)

**Perspective**: [unique angle]
**Expertise**:
- [area 1]
- [area 2]
- [area 3]

**Analysis Framework**: [methodology]

**Key Questions**:
1. [question 1]
2. [question 2]
3. [question 3]

**Risk Detection**:
- [risk 1]
- [risk 2]

### Agent Prompt

<Expert_Prompt>
  <Role>...</Role>
  <Expertise>...</Expertise>
  <Analysis_Framework>...</Analysis_Framework>
  <Output_Format>
    ## [Role] Review

    ### Rating: APPROVE / CONCERN / BLOCK
    ### Strengths (2-3 items)
    ### Concerns (specific risks from this perspective)
    ### Recommendations (concrete changes)
    ### Missed Perspectives
    ### Purpose Validation
    - Problem this plan solves: [1 line]
    - Does the proposed approach actually solve it: [yes/no — rationale]
    - Gaps or blind spots: [if any]
  </Output_Format>
  <Constraints>...</Constraints>
</Expert_Prompt>
```

For reuse-agent type:
```markdown
## Expert 1: Architect (reuse existing agent)

**Profile-Type**: reuse-agent
**Source**: `agents/architect.md`
**Agent Prompt**: (use existing agent prompt, override output format for plan-review)
```

### Phase 5: User Confirmation

Show panel summary and ask for approval:
```
## Expert Panel Assembled

- **Topic**: [topic]
- **Domain**: [domain]
- **Panel file**: docs/plans/expert-panel-{slug}.md

| # | Role | Perspective | Type |
|---|------|-------------|------|
| 1 | ... | ... | custom/reuse |

Adjust panel? (change/add/remove/approve)
```

Proceed after user approval. If called from `/plan-review`, auto-continue to next phase.

$ARGUMENTS
