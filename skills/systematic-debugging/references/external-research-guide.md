# External Research Guide

## Overview

When encountering errors, don't fix from self-knowledge alone. Find evidence from official external sources first.

**Core principle: No fix without external research. LLM self-knowledge may be outdated or inaccurate.**

## When to Use

- Error messages/codes appear (Phase 0 and Phase 1)
- Library API usage is uncertain
- Behavior changed after dependency update
- Environment/runtime differences suspected

## Search Procedure by Type

### 1. Error-Based Search

1. Extract **key terms** from error message (library name, error code, unique message)
2. **context7** for official library docs:
   - `resolve-library-id` → get library ID
   - `query-docs` → search with error message/code
3. **Web search** for GitHub Issues/Stack Overflow:
   - Search: "error message + library name + github issue"
   - Read promising results in detail

### 2. Dependency-Based Search

1. Check package@current-version
2. Search: "[package] changelog [version]" or "[package] breaking changes [version]"
3. Read release notes/CHANGELOG in full
4. Check compatibility matrices if available

### 3. Environment-Based Search

1. Runtime version + error keyword combination
2. Search: "[runtime] [version] [error keyword] known issue"
3. Check runtime-specific known issues (Node.js issues, Deno issues, etc.)

## Search Priority (by authority)

1. **Official docs** (context7) — most accurate and current
2. **GitHub Issues** — official issue tracker
3. **Stack Overflow** — community-verified solutions
4. **General web search** — blogs, forums

Stop at the first level that provides an answer.

## Phase 0 vs Phase 1 Research

| | Phase 0 | Phase 1 |
|---|---------|---------|
| **Purpose** | Is this a known issue? | Why does this behavior occur? |
| **Depth** | Exact match search (5 min max) | Deep reading of cause mechanism |
| **Action** | Keyword search → solution exists? | Read official docs → understand cause |
| **Result** | "Known issue" / "Not known" | "This code fails because..." |

## When Tools Are Unavailable

If MCP tools (context7, jina-reader, exa) are not accessible:

1. **Record key terms** from the error message
2. **List cause candidates** from self-knowledge, marking each as **'unverified hypothesis'**
3. **Report to user**: "MCP tools unavailable. Proceeding with N unverified hypotheses. External verification recommended when possible."
4. Unverified hypothesis fixes must go through Phase 1 full process (no Phase 0 quick-fix)

## Key Takeaway

**Even if you "know" the answer, verify with external sources.** LLM confidence is not evidence of accuracy.
