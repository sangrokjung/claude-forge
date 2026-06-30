# Renderer — Claude Code slash command

> Picture a **translator**. It takes the neutral loop spec (a parts spec sheet bound
> to no platform) and re-expresses it in the grammar Claude Code understands — a slash
> command at `.claude/commands/<name>.md`. The content (skeleton · verifier · hardstop
> · done signal) is untouched; only the invocation grammar (`/<name>`, `$ARGUMENTS`) is
> dressed in Claude Code's syntax.

---

## Consumes / produces

- **Consumes**: one loop spec object (conforms to `references/loop-spec-schema.md` /
  `tools/loop_spec.schema.json`, built by `assembler.md`). Only a spec that
  `check_safety.py` cleared with exit 0 is eligible to render.
- **Produces**: one `.claude/commands/<name>.md` text. Saved as-is, it becomes a
  reusable command you can call with `/<name>`.

## Save-location rule (scope branch)

The spec's `scope` field decides the save path — the value the user picked in Stage 6
("this project only" vs. "anywhere").

| `scope` | Save path | Meaning |
|---|---|---|
| `project` | `<cwd>/.claude/commands/<name>.md` | `/<name>` shows only in the current project (project-local, the default) |
| `global` | `~/.claude/commands/<name>.md` | `/<name>` shows in every project (the global harness) |

- `<name>` is the spec's `name` field (slug, `^[a-z][a-z0-9-]{1,30}$`). Filename =
  `<name>.md`.
- `mkdir -p` the directory if it's missing. If a file with that name already exists,
  **confirm with the user before overwriting** (protect their existing command).

## Spec field → command-file section mapping (canonical)

| Command-file location | Source (loop spec field) | Note |
|---|---|---|
| frontmatter `description` | `situation` + `label` | one-line summary in the form "<situation> (<Label> loop)" |
| frontmatter `argument-hint` | (input hint) | the variant input the user passes at call time. A plain bracketed hint for non-developers (e.g. `[input file path — blank for the default]`) |
| title (`# /<name> — …`) + **analogy** | `name` + that `archetypes/<shape>.md` analogy | so a non-developer grasps "what kind of loop this is" in one line |
| `## Input: $ARGUMENTS` | (invocation-variable convention) | see "The `$ARGUMENTS` convention" below |
| `## Procedure` | `skeleton` | the numbered procedure the assembler built by slot substitution. The `gate` (e.g. `N ≤ max_items`) is already baked into step 1 of the skeleton |
| `## Verifier (auto)` | `registry.verifier` | the maker ≠ checker inspector. **Copy verbatim (no summarizing, no variation).** |
| `## Hardstop` | `registry.hardstop` | the budget · count · cooldown stop. **Copy verbatim.** |
| `## Done signal` | `registry.accepted_signal` | the observed signal that counts as "done." **Copy verbatim.** |
| `## How to run` (footer) | `registry.trigger` | how `/<name>` runs (for Watch, the condition/interval) |

> `registry.gate` gets no section of its own — the gate is a "condition check" inside
> the procedure flow, so it's already embedded in `skeleton` (`## Procedure`), e.g.
> batch step 1: "if N > {max_items}, stop and report."

## Language note (English skeleton, localized content)

The stamped command's **section skeleton is fixed English** —
`## Procedure / ## Verifier (auto) / ## Hardstop / ## Done signal` — so every loop is
diagnosable against the same frame regardless of the user's language. But loop-forge
**fills the body in the user's own language**: the `description`, the analogy, the
procedure prose, and the verifier/hardstop/done-signal text all render in the same
language as `situation` and `slots` (the language the interview was conducted in). The
skeleton is the universal shape; the content auto-adapts. The interview is run, and the
loop is stamped, in the user's language.

## frontmatter rules

```yaml
---
description: <situation summary> (<Label> loop)
argument-hint: <plain bracketed input hint>
---
```

- `description` compresses the **user's original situation into one line** + the shape
  label, so a non-developer recognizes their own command in the `/` autocomplete list.
- `argument-hint` describes the **variant input** to pass at call time. It's optional,
  but a stamped loop is usually "reused on a different file/topic," so include it.
- No jargon — a non-developer reads this line.

## The `$ARGUMENTS` convention

- **Take the variant input through `$ARGUMENTS` and inject it into the skeleton.** The
  whole value of a stamp = "build once, reuse by swapping the input."
- In the `## Input: $ARGUMENTS` section, state the **empty-input fallback**: if
  `$ARGUMENTS` is empty, use the spec slot's default input (e.g. batch's
  `input_source`); if it has a value, that value overrides the relevant slot (usually
  the input source/target).
- For shapes that need multiple arguments (e.g. changing Explore's candidate count),
  take `$ARGUMENTS` as natural language and interpret it inside the procedure (Claude
  Code's `$1`–`$9` positional args also work, but prefer natural-language `$ARGUMENTS`
  for non-developers).
- **User input must never weaken the hardstop (budget · count · cooldown).** Even if
  `$ARGUMENTS` asks to raise `max_items`, the ceiling in `## Hardstop` keeps the spec
  value — a safety device can't be turned off by a call argument.

## Equivalence (the contract with the Portable Prompt render)

- This renderer and `references/renderers/portable-prompt.md` are produced from **one**
  loop spec. The `## Procedure` (skeleton) · `## Verifier (auto)` (verifier) ·
  `## Hardstop` (hardstop) · `## Done signal` (accepted_signal) **bodies must be
  identical on both sides**.
- The only difference is the **invocation/variable syntax**: Claude Code = frontmatter
  + `$ARGUMENTS` + `/<name>`; Portable Prompt = a paste-able block
  (`codex-prompt-mechanism.md` `decision: FALLBACK` by default) with a paste header + a
  usage footer. Identical skeleton + safety devices is what guarantees an "equivalent
  stamp on both sides."

## Output body skeleton (render in this order)

```markdown
---
description: <situation summary> (<Label> loop)
argument-hint: <input hint>
---

# /<name> — <short title> (<Label>)

> Analogy: <the one-line analogy from archetypes/<shape>.md>

## Input: $ARGUMENTS

If $ARGUMENTS is set, use it as <the relevant slot>; if empty, use the default
<spec default input>.

## Procedure

<the skeleton's numbered procedure, as-is>

## Verifier (auto)

> <registry.verifier verbatim — maker ≠ checker>

## Hardstop

> <registry.hardstop verbatim — budget · failure ceiling>

## Done signal

> <registry.accepted_signal verbatim>

## How to run

Run `/<name>` (<registry.trigger>). To change the input, run `/<name> <new input>`.
```

> The title, analogy, and body prose render in the user's language; the section
> headings stay the fixed English skeleton shown above.

## Self-check (right after rendering)

- frontmatter has both `description` and `argument-hint`.
- the body has `$ARGUMENTS` at least once (with the empty-input fallback stated).
- `## Verifier (auto)` carries `registry.verifier` (especially the `maker ≠ checker`
  idea) verbatim.
- `## Hardstop` carries `registry.hardstop` (budget cap + failure-ceiling/cooldown)
  verbatim.
- `## Done signal` carries `registry.accepted_signal` verbatim.
- the body content is in the user's language (gloss any first-use English jargon in
  plain words); only the section headings are the fixed English skeleton.

## Related

- `references/loop-spec-schema.md` — the input spec contract (9 fields + the 5 registry
  cells)
- `references/assembler.md` — the assembler that builds the spec (this renderer's
  supplier) + the safety auto-injection
- `references/renderers/portable-prompt.md` — the same spec's Portable Prompt output
  (skeleton · verifier · hardstop · done signal identical, only the invocation differs)
- `references/codex-prompt-mechanism.md` — the decision (FALLBACK/native) behind the
  Portable Prompt output
- `tools/examples/batch/claude-command.md` — the golden output for these rules (ground
  truth)
- `tools/check_safety.py` — the static safety check before render (only exit 0 renders)
