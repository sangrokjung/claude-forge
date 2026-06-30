# Renderer — Portable Prompt

> Picture **a translator that re-expresses the same parts spec sheet (loop spec) for
> the shop next door — and the one after that.** The content (skeleton · verifier ·
> hardstop · done signal) stays **byte-identical** to the Claude Code render; only the
> invocation is dressed differently. Because an agent's native "stamp my command"
> drawer (Codex's) has been deprecated by its vendor, the default export is a
> **paste-able prompt** (FALLBACK) that runs in any agent — Codex, Cursor, ChatGPT, and
> the rest.

---

## Governed by the codex-prompt-mechanism decision (FALLBACK by default)

This renderer's branch follows the `decision` field in
`references/codex-prompt-mechanism.md` (§0) **as-is**. The current decision:

- **`decision: FALLBACK`** (canonical) — a native custom-prompt file (e.g. Codex's
  `~/.codex/prompts/<name>.md` → `/name`) exists, but OpenAI has publicly deprecated it
  ("Use skills for reusable prompts"), the official migration routes around the native
  slash runtime via skills, and recent CLI versions have regressed its surfacing
  (`openai/codex` #15941). So the Portable Prompt output renders as a **paste-able
  prompt text block**.
- If a later human re-measure flips `decision` to `NATIVE`, switch to the
  "Native promotion" branch below (the re-measure path is in codex-prompt-mechanism.md
  §4).

> ⚠️ Check codex-prompt-mechanism.md once before rendering. If `decision` changes, this
> renderer's default branch changes with it.

## Consumes / produces

- **Consumes**: one loop spec object (conforms to `references/loop-spec-schema.md` /
  `tools/loop_spec.schema.json`, built by `assembler.md`) +
  codex-prompt-mechanism.md's `decision`/`directory`/`variable_convention`. Only a spec
  that `check_safety.py` cleared with exit 0 is eligible to render.
- **Produces**: one Portable Prompt text.
  - **FALLBACK**: a paste-able prompt (a top usage header + a body identical to Claude
    Code's). Save it as `<name>-portable-prompt.md` or present it on screen → the user
    pastes it into their agent.
  - **NATIVE** (optional): `{directory}/<name>.md` (e.g. `~/.codex/prompts/<name>.md`),
    a plain prompt with no frontmatter + the native variable convention.

## Spec field → Portable Prompt section mapping (canonical)

| Portable Prompt location | Source (loop spec field) | Relation to the Claude Code render |
|---|---|---|
| top usage header (FALLBACK) / none (NATIVE) | (invocation note) | **the difference** — CC uses frontmatter; the FALLBACK uses a paste header |
| title (`# <name> — …`) + **analogy** | `name` + that `archetypes/<shape>.md` analogy | same (FALLBACK drops the leading `/` — it's not a slash command) |
| `## Input` | (invocation-variable convention) | **the difference** — CC `## Input: $ARGUMENTS` ↔ here, the variable convention / paste note |
| `## Procedure` | `skeleton` | **identical (as-is)** — not one character of the numbered procedure changes |
| `## Verifier (auto)` | `registry.verifier` | **identical (as-is)** — the maker ≠ checker inspector |
| `## Hardstop` | `registry.hardstop` | **identical (as-is)** — budget · failure ceiling · cooldown |
| `## Done signal` | `registry.accepted_signal` | **identical (as-is)** |
| `## How to run` (footer) | `registry.trigger` | **the difference** — CC `/<name>` ↔ here, paste (FALLBACK) / `/prompts:<name>` (NATIVE) |

> `registry.gate` gets no section of its own — the gate is already baked into
> `skeleton` (`## Procedure`), same as the Claude Code render.

## Language note (English skeleton, localized content)

Same as the Claude Code render: the **section skeleton is fixed English**
(`## Procedure / ## Verifier (auto) / ## Hardstop / ## Done signal`), but loop-forge
**fills the body in the user's own language** (the language of `situation` and
`slots`). The skeleton is the shared frame; the content auto-adapts. The interview is
run, and the loop is stamped, in the user's language.

## FALLBACK branch (the default — codex-prompt-mechanism canonical)

Render as a paste-able prompt (codex-prompt-mechanism.md §3).

1. **Top usage header (one line)**: "Paste this prompt into your agent to run it (fill
   the inputs as the body indicates)."
2. **Deprecation note (a blockquote)**: in 1–2 lines, say the native custom-prompt
   mechanism is deprecated/unverified, so this is a paste-able prompt; and that the
   **skeleton · verifier · hardstop · done signal are 100% identical** to the Claude
   Code `/<name>` command — the only difference is the invocation (slash vs. paste).
3. **The body to paste** (these four sections are **byte-identical** to the Claude Code
   render):
   - title + analogy (the title drops the `/` → `# <name> — …`)
   - `## Input` — the default input + "to run it on different input, edit the input
     source in the procedure directly." Show the native variable convention
     (`$ARGUMENTS`/`$1`) as a one-line reference only (codex-prompt-mechanism.md §4).
   - `## Procedure` — the `skeleton`, as-is
   - `## Verifier (auto)` — `registry.verifier`, as-is (+ the same explanatory
     paragraph as the Claude Code example)
   - `## Hardstop` — `registry.hardstop`, as-is (+ the same paragraph)
   - `## Done signal` — `registry.accepted_signal`, as-is (+ the same paragraph)
4. **How-to-run (paste) footer**: tell the user to "copy the whole block from the title
   through the Done signal and paste it into your agent session (interactive, or
   `codex exec '...'`) to run." Reuse the same loop = swap the input and paste again.
   State that **the safety ceilings (budget · count · cooldown) cannot be raised by
   paste arguments.**

## Native promotion (optional — only if the user accepts the deprecation risk)

If `decision` is `NATIVE`, or the user explicitly says "I want to call it with `/name`
in my agent too" (codex-prompt-mechanism.md §4):

- **Path**: `{directory}/<name>.md` (e.g. `~/.codex/prompts/<name>.md`). `mkdir -p` if
  absent; confirm before overwriting an existing file.
- **Format**: a plain prompt with **no** frontmatter (the native convention). The body
  is the same title · `## Procedure` · `## Verifier (auto)` · `## Hardstop` ·
  `## Done signal` as the FALLBACK.
- **Variables**: substitute with `{variable_convention}` — `$1`–`$9` (positional) ·
  `$ARGUMENTS` (the whole input) · `$NAME` (named, passed as `KEY=value`) · `$$` (a
  literal `$`). These map 1:1 to Claude Code's `$ARGUMENTS`/`$1`.
- **Invocation**: in the interactive TUI, `/` → `/prompts:<name>` (some versions accept
  `/<name>`).
- **Mandatory warning**: "Native custom prompts are deprecated by OpenAI and have a
  history of not appearing in some versions (#15941), so their behavior isn't
  guaranteed. The paste-able prompt is recommended by default." Carry this line at the
  top of the output or alongside the guidance.

## Equivalence (the contract with the Claude Code render — CRITICAL)

- This renderer and `references/renderers/claude-code.md` derive from **one** loop spec.
  The `## Procedure` (skeleton) · `## Verifier (auto)` (verifier) · `## Hardstop`
  (hardstop) · `## Done signal` (accepted_signal) **bodies must be identical on both
  sides** (no summarizing, no variation).
- The only allowed difference is the **invocation/variable syntax**: CC = frontmatter +
  `$ARGUMENTS` + `/<name>`. FALLBACK = a top paste header + `## Input` /
  `## How to run (paste)`. NATIVE = no frontmatter + native variables + `/prompts:<name>`.
- This identity of the skeleton + safety devices is what guarantees the "equivalent
  stamp on both sides." A diff of the two outputs must be confined to the
  invocation/variable lines.

## Output body skeleton — FALLBACK (render in this order)

```markdown
# Paste this prompt into your agent to run it (fill the inputs as the body indicates)

> Native custom-prompt stamping is deprecated and not guaranteed to work (see
> codex-prompt-mechanism.md), so this output is a **paste-able prompt** — paste the
> whole body below into your agent session. The skeleton · verifier · hardstop · done
> signal are 100% identical to the Claude Code `/<name>` command; the only difference
> is the invocation (slash vs. paste).

---

# <name> — <short title> (<Label>)

> Analogy: <the one-line analogy from archetypes/<shape>.md>

## Input

The default input is `<spec default input>`. To run it on different input, edit the
input source in the procedure below to that value. (When stamped as a native custom
prompt, the input comes in via `$ARGUMENTS`/`$1` — but that path is deprecated, see
codex-prompt-mechanism.md §4.)

## Procedure

<the skeleton's numbered procedure, as-is>

## Verifier (auto)

> <registry.verifier verbatim — maker ≠ checker>

<the same explanatory paragraph as the Claude Code example>

## Hardstop

> <registry.hardstop verbatim — budget · failure ceiling>

<the same explanatory paragraph>

## Done signal

> <registry.accepted_signal verbatim>

<the same explanatory paragraph>

## How to run (paste)

Copy the whole block from "<name> —" through "Done signal" and paste it into your agent
session (interactive, or `codex exec '...'`) to run. To reuse the same loop on
different input, change only the input source and paste again. The safety ceilings
(budget · count · cooldown) cannot be raised by paste arguments.
```

> The title, analogy, and body prose render in the user's language; the section
> headings stay the fixed English skeleton shown above.

## Self-check (right after rendering)

- the codex-prompt-mechanism `decision` branch is reflected — FALLBACK → a top paste
  header + `## How to run (paste)`; NATIVE → path/variables/deprecation warning.
- the `## Procedure` · `## Verifier (auto)` · `## Hardstop` · `## Done signal` bodies
  are **identical to the Claude Code example** (especially the verifier `maker ≠
  checker` and the hardstop budget cap + failure ceiling).
- the skeleton procedure maps 1:1 to `claude-command.md` (a diff is confined to
  invocation/variable lines).
- the body content is in the user's language (gloss any first-use English jargon in
  plain words); only the section headings are the fixed English skeleton.

## Related

- `references/codex-prompt-mechanism.md` — **the canonical decision (NATIVE/FALLBACK)** —
  required reading before render
- `references/loop-spec-schema.md` — the input spec contract (9 fields + the 5 registry
  cells)
- `references/assembler.md` — the assembler that builds the spec (this renderer's
  supplier) + the safety auto-injection
- `references/renderers/claude-code.md` — the same spec's Claude Code output (skeleton ·
  verifier · hardstop · done signal identical, only the invocation differs)
- `tools/examples/batch/portable-prompt.md` — the golden output for these rules (ground
  truth, FALLBACK)
- `tools/examples/batch/claude-command.md` — the paired output for the equivalence check
- `tools/check_safety.py` — the static safety check before render (only exit 0 renders)
