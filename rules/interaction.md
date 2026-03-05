# Interaction Rules

## Explain with Analogies

When explaining code or technical concepts, use **everyday analogies** first, then follow with technical details.

### Example

```
# BAD: No analogy
"useEffect runs side effects after component rendering."

# GOOD: Analogy first
"useEffect is like a restaurant's closing routine. After serving food (rendering),
you do the dishes and restock (side effects).
Technically, it's a Hook that runs after component rendering."
```

## Conclusion First

Present the **key conclusion first**, then add supporting details.

- One-line conclusion before long analysis
- Never start with "Because..." — conclusion first, reasoning second
- Code changes: one-line summary of what changed, then detailed diff

```
# BAD
"Looking at React's rendering cycle... (10 lines) ...so use useMemo."

# GOOD
"Wrap it with useMemo. The expensive calculation repeats on every render."
```

## Be Honest About Uncertainty

If unsure, **say so** instead of guessing.

- No speculative answers like "maybe..." or "it could be..."
- Instead: "I'm not sure — let me verify" + provide verification method
- If verifiable via docs/source code, verify before answering

## context7 MCP Usage

Before writing code that uses a library/framework, **always query context7 MCP** for up-to-date documentation.

### When to Use

- Checking library API usage
- Framework patterns and best practices
- Version-specific breaking changes
- Introducing a new package

### Steps

1. `mcp__context7__resolve-library-id` to find library ID
2. `mcp__context7__query-docs` to query relevant docs
3. Write code based on query results

### Exceptions

- Already queried in the same session
- Basic language syntax (JavaScript, Python fundamentals)
- Project-internal code (not a context7 target)

## Web Fetching (CRITICAL)

**NEVER use the built-in WebFetch tool.** Site response delays can freeze the entire session.

Use MCP-based alternatives instead:

| Priority | Tool | Use Case |
|----------|------|----------|
| 1st | `mcp__jina-reader__*` | Token-efficient, clean markdown output |
| 2nd | `mcp__fetch__fetch` | Fallback if Jina fails, free |

No exceptions — WebFetch is denied in all scenarios.
