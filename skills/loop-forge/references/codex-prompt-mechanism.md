# Codex prompt mechanism — why the secondary export is a paste-able block

> Picture checking whether the shop next door (Codex) has its own "stamp my command"
> drawer — and if it does, which drawer (path), how you call it (`/name`), and how the
> blanks get filled (`$1`). This one decision drives how loop-forge's **secondary,
> harness-agnostic export** (`references/renderers/portable-prompt.md`) renders.

The primary loop-forge output is always a **Claude Code slash command**
(`references/renderers/claude-code.md`). This note explains the **secondary** output —
the **Portable Prompt** — and why it's a paste-able prompt block rather than a
harness-native "custom prompt" file.

---

## 0. Decision first

**`decision: FALLBACK`** → render the secondary output as a **Portable Prompt**: a
paste-able prompt text block plus a one-line "paste this into your agent" header.

Several agents (Codex among them) have a native "custom prompts" mechanism — a
Markdown file in a home directory, invoked as a slash command with positional
variables. But OpenAI has **publicly deprecated** Codex's custom prompts ("Use
skills for reusable prompts"), and the official migration tooling converts
`.claude/commands/*.md` into **skills** while preserving slash-invocation and
`$ARGUMENTS` only as **manual-review (non-runtime) text** — i.e. it does not rely on
the native slash runtime. Combined with reports of the feature failing to appear in
recent CLI versions, runtime `/name` invocation is **not dependably verifiable**.

So loop-forge takes the durable route: the body (skeleton · verifier · hardstop ·
accepted signal) is **byte-identical** to the Claude Code render; only the invocation
differs (you paste the block instead of typing `/name`). This export works in any
agent — Codex, Cursor, ChatGPT, etc. The native variable convention is recorded below
as an **optional** path for users who accept the deprecation risk.

---

## 1. Output fields

| Field | Value |
|---|---|
| `directory` (native, optional) | `~/.codex/prompts/` (= `$CODEX_HOME/prompts/`, per the public docs; not created by default — the user must `mkdir` it) |
| `invocation` (native, optional) | in the interactive TUI, open the slash menu with `/` and call `/prompts:<name>` (or the prompt name). It is **not** a CLI subcommand/flag, so it doesn't show in `--help` or shell completion, and it is **deprecated**. |
| `variable_convention` | `$1`–`$9` (space-separated positional args) · `$ARGUMENTS` (the whole input) · `$NAME` (named, passed as `KEY=value`; quote values with spaces, e.g. `FOCUS="loading state"`) · `$$` (a literal `$`). This is the **same family** as Claude Code's `$ARGUMENTS`/`$1`. |
| `decision` | **FALLBACK** (Portable Prompt) |

---

## 2. Why FALLBACK is the durable choice

| Observation (public sources) | Implication |
|---|---|
| OpenAI's Custom Prompts doc marks the feature **DEPRECATED** ("Use skills for reusable prompts") | a future release may remove it → a native-prompt artifact would break |
| The official Claude→Codex migration converts commands to **skills**, keeping slash-invocation + `$ARGUMENTS` as **manual-review text** | the vendor itself does not depend on the native slash runtime |
| GitHub `openai/codex` #15941: custom prompts in `~/.codex/prompts` stopped appearing after a CLI update | a recent regression in surfacing the feature |
| A paste-able prompt block has **no dependency** on any native prompt mechanism | it is forward-compatible — it always works regardless of version/feature changes |
| loop-forge must not reimplement a skill builder (a non-goal) | so it doesn't emit a "skill" (the official replacement) either → the most durable export is a paste-able prompt |

→ **The most durable, harness-agnostic Codex/other-agent output is a paste-able
prompt block.**

---

## 3. FALLBACK render (the canonical secondary output)

The Portable Prompt is a paste-able block (rendered by
`references/renderers/portable-prompt.md`):

- **Top header (one line)**: "Paste this prompt into your agent to run it (fill the
  inputs as the body indicates)."
- **A short note** that the native custom-prompt mechanism is deprecated/unverified,
  so this is a paste-able prompt; and that the **skeleton · verifier · hardstop ·
  accepted signal are 100% identical** to the Claude Code `/name` command — the only
  difference is the invocation (slash vs. paste).
- **The body** (these four sections are **byte-identical** to the Claude Code render):
  - title + analogy (the title drops the leading `/` — it's not a slash command)
  - `## Input` — the default input + "to run it on different input, edit the input
    source in the procedure directly." Show the native variable convention
    (`$ARGUMENTS`/`$1`) as a one-line reference only.
  - `## Procedure` — the `skeleton`, as-is
  - `## Verifier (auto)` — `registry.verifier`, as-is (maker ≠ checker)
  - `## Hardstop` — `registry.hardstop`, as-is
  - `## Done signal` — `registry.accepted_signal`, as-is
- **Footer (how to run by pasting)**: "Copy the whole block from the title through the
  Done signal and paste it into your agent session (interactive, or `codex exec
  '...'`) to run. To reuse the same loop on different input, change only the input
  source and paste again. **The safety ceilings (budget · count · cooldown) cannot be
  raised by call arguments.**"

---

## 4. Optional native promotion (only if the user accepts the deprecation risk)

If the user explicitly says "I want to call it with `/name` in Codex too," the same
body can be placed natively (with a deprecation warning):

- **Path**: `~/.codex/prompts/<name>.md` (= `{directory}/<name>.md`). Create the dir
  if absent; confirm before overwriting an existing file.
- **Format**: a plain prompt with **no** frontmatter (Codex convention). The body is
  the same title · `## Procedure` · `## Verifier (auto)` · `## Hardstop` · `## Done
  signal` as the FALLBACK.
- **Variables**: substitute with `{variable_convention}` — `$1`–`$9` (positional) ·
  `$ARGUMENTS` (whole) · `$NAME` (named, `KEY=value`) · `$$` (literal `$`). These map
  1:1 to Claude Code's `$ARGUMENTS`/`$1`.
- **Invocation**: in the interactive TUI, `/` → `/prompts:<name>` (some versions
  accept `/<name>`).
- **Mandatory warning**: "Codex custom prompts are deprecated by OpenAI and have a
  history of not appearing in some versions (#15941), so their behavior isn't
  guaranteed. The paste-able prompt is recommended by default."

If a person verifies in an interactive TUI that `/prompts:<name>` is recognized and
`$1` substitution works in their installed version, this note's §0 `decision` may be
updated to `NATIVE` (a re-measure path). It remains deprecated, so it isn't
recommended.

---

## 5. Equivalence contract (with the Claude Code render — CRITICAL)

- This renderer and `references/renderers/claude-code.md` derive from **one** loop
  spec. The `## Procedure` (skeleton) · `## Verifier (auto)` (verifier) · `##
  Hardstop` (hardstop) · `## Done signal` (accepted_signal) bodies must be **identical
  across both outputs** (no summarizing, no variation).
- The only allowed difference is the **invocation/variable syntax**: Claude Code =
  frontmatter + `$ARGUMENTS` + `/name`; Portable Prompt FALLBACK = a top paste header
  + `## Input`/paste footer; native (optional) = no frontmatter + native variables +
  `/prompts:name`.
- This identity of the skeleton + safety devices is what guarantees the "equivalent
  stamp on both sides." A diff of the two outputs must be confined to the
  invocation/variable lines.

## 6. One-line rationale

Native custom prompts **exist but are deprecated**, the vendor's own migration routes
around them via skills, and recent versions have regressed their surfacing → the
durable, harness-agnostic export is a **paste-able Portable Prompt**. The variable
convention (`$1`/`$ARGUMENTS`) is recorded so an optional native promotion stays
available.

## 7. Sources (public, primary-first)

- [Custom Prompts — Codex | OpenAI Developers](https://developers.openai.com/codex/custom-prompts) (marks the feature DEPRECATED + the variable convention)
- [Slash commands — Codex CLI | OpenAI Developers](https://developers.openai.com/codex/cli/slash-commands)
- [Custom prompts in ~/.codex/prompts no longer appear after a CLI update · Issue #15941 · openai/codex](https://github.com/openai/codex/issues/15941)
- [Custom prompts — passing arguments · Issue #2890 · openai/codex](https://github.com/openai/codex/issues/2890)

## 8. Related

- `references/renderers/portable-prompt.md` — the renderer that consumes this decision
  (FALLBACK = paste-able block)
- `references/renderers/claude-code.md` — the primary output; the equivalence-contract
  counterpart
- `references/loop-spec-schema.md` — the input spec contract (9 fields + the 5
  registry cells)
- `references/assembler.md` — produces the spec (with auto-injected safety) that both
  renderers consume
