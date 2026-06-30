# Loop spec schema — the contract between all parts

> Picture a **parts spec sheet**. Whatever factory (shape) you're in, the same boxes
> must be filled for assembly. The classifier · interviewer · assembler · renderers
> don't need to speak each other's language — they just hand around this one sheet.

## 1. What it is

The **single type** the four internal parts (classifier → interviewer → assembler →
renderers ×2) pass around, from a non-developer's one-line situation all the way to a
**reusable `/command` stamp**. It's **neutral JSON** not bound to any platform, and
its machine-validation schema is the sibling file `tools/loop_spec.schema.json`
(jsonschema — a rule sheet that automatically checks "does this JSON match the
spec?").

Core design: **the loop-registry's 5 cells (trigger / gate / verifier / hardstop /
accepted signal) are first-class under the `registry` field.** So every loop this
tool stamps is born in a shape that's diagnosable at a glance against the loop-
registry frame.

## 2. Field table (all 9 fields required)

| Field | Type | Filled by | Description |
|---|---|---|---|
| `name` | string `^[a-z][a-z0-9-]{1,30}$` | interviewer | the `/command` name (slug). Starts lowercase, then lowercase/digits/hyphens, 2–31 chars. e.g. `review-summary`. A non-Latin answer is transliterated/semantically slugged to ASCII and confirmed |
| `archetype` | enum `batch｜pipeline｜refine｜watch｜explore` | classifier | one of the 5 loop shapes. Canonical and language-neutral. No 6th shape (YAGNI) |
| `label` | string | classifier | the shape's canonical English label: Batch / Pipeline / Refine / Watch / Explore (rendered in the user's language at stamp time) |
| `situation` | string | entry | the user's original one-line situation, verbatim (any language) |
| `scope` | enum `project｜global` | interviewer | stamp save location. `project`=`<cwd>/.claude/commands`, `global`=`~/.claude/commands`. Chosen in Stage 6 |
| `slots` | object | interviewer | per-shape slot key=value. Keys are English/canonical, defined by that `archetypes/<shape>.md` (e.g. batch=`input_source/per_item_task/output_format/max_items`); values are the user's answers (any language) |
| `skeleton` | string | assembler | the procedure body with slot variables substituted. `{slot}` placeholders filled with the user's answers |
| `external_action` | boolean | interviewer/assembler | whether it sends/posts outbound. `true` raises the outbound-gate bar (dry-run/human approval first). **Watch defaults to `true`** |
| `registry` | object (6 cells) | assembler | the 5 loop-registry cells + the added `external_gate` enum. See §3. The 5 cells are non-empty strings |

> Schema enforces: all 9 fields `required`, `additionalProperties:false` (typo
> guard), `archetype`·`scope` enums, the `name` regex pattern, all 5 registry cells
> `required` + `minLength≥1` (no blanks), and the `external_gate` enum.

## 3. The loop-registry 5 cells ↔ `registry` fields (1:1), plus `external_gate`

The 5 cells of the `registry` object *are* the loop-registry's 5 cells. **Only
`trigger` has a default (manual `/command`); the assembler auto-injects the other 4
from the archetype catalog (`archetypes/<shape>.md`)** — the tool fills what a
non-developer doesn't even know to ask for (an inspector and a stop switch).

| loop-registry cell | `registry` field | Who fills it | Meaning (plain) |
|---|---|---|---|
| trigger | `trigger` | default = manual `/command` run (Watch only = condition/interval) | when the loop fires |
| gate | `gate` | assembler (shape mapping) | the entry/stage-pass condition (e.g. batch = `N ≤ max_items`) |
| verifier (inspector) | `verifier` | assembler (auto-injected default) | maker ≠ checker. For watch/external_action, the verifier prose describes the outbound gate (dry-run / human approval) |
| hardstop (stop switch) | `hardstop` | assembler (auto-injected default) | the budget · count · cooldown ceiling (stops "a loop that quietly breaks while burning money") |
| accepted signal | `accepted_signal` | assembler (shape mapping) | the observation that counts as "done" (e.g. N rows present in output + a failure-log count) |

Plus one **language-independent enum** that makes the Watch safety check pass in any
language:

| Added field | `registry` field | Values | Rule |
|---|---|---|---|
| outbound gate | `external_gate` | enum `dry_run｜human_approval｜none` | If `archetype == "watch"` or `external_action == true`, must be `dry_run` or `human_approval` (never `none`). `check_safety.py` enforces on the **enum**, not on prose |

## 4. Example — one Batch loop

The loop spec for "summarize 100 shop reviews." It passes
`tools/loop_spec.schema.json` (validated).

```json
{
  "name": "review-summary",
  "archetype": "batch",
  "label": "Batch",
  "situation": "I want to summarize 100 shop reviews into 3 lines each",
  "scope": "project",
  "slots": {
    "input_source": "a reviews CSV (reviews.csv)",
    "per_item_task": "summarize one review into 3 lines",
    "output_format": "a summary.md table (rows = reviews, columns = excerpt · 3-line summary)",
    "max_items": 100
  },
  "skeleton": "1) Load the list from the reviews CSV (reviews.csv) and count the total N. If N > 100, do not process — stop and report.\n2) For each review: summarize one review into 3 lines → accumulate the result.\n3) Save as a summary.md table (rows = reviews, columns = excerpt · 3-line summary).\n4) [verifier] Count-match input N against output N (flag missing/duplicate), then re-check a random K = min(5, N) in a SEPARATE pass, not right after generation (maker ≠ checker).\n5) [hardstop] 3 failures on one item → skip + log; if the cumulative failure rate passes 20%, abort.",
  "external_action": false,
  "registry": {
    "trigger": "manual /review-summary run",
    "gate": "N ≤ 100 (max_items)",
    "verifier": "count-match input N vs output N (flag missing/duplicate) + re-check a random K in a separate pass, not by the generator (maker ≠ checker)",
    "hardstop": "max_items 100 budget cap · 3 failures per item → skip + log (not a full stop) · abort when cumulative failure rate > 20%",
    "accepted_signal": "N rows present in summary.md + a count of the failure log (skip list)",
    "external_gate": "none"
  }
}
```

## 5. How to validate

```bash
cd skills/loop-forge/tools
# (a) is the schema itself a valid jsonschema?
uv run --with jsonschema python -c "import json,jsonschema; s=json.load(open('loop_spec.schema.json')); jsonschema.Draft202012Validator.check_schema(s); print('schema OK')"
# (b) does a given spec match the schema? (e.g. the assembler's output spec.json)
uv run --with jsonschema python -c "import json,jsonschema,sys; s=json.load(open('loop_spec.schema.json')); jsonschema.Draft202012Validator(s).validate(json.load(open(sys.argv[1]))); print('spec OK')" examples/batch/spec.json
```

The assembler's static safety check (`tools/check_safety.py`) calls (b) as step 1,
then additionally enforces verifier/hardstop non-empty and the Watch `external_gate`
enum.

## 6. Related

- `tools/loop_spec.schema.json` — the canonical machine-validation schema for this
  spec
- `references/archetypes/<shape>.md` — the source of `slots` keys · `skeleton` ·
  `registry` defaults (the archetype catalog)
- `references/assembler.md` — slots + skeleton → this spec + the `registry`
  auto-injection rules
- `references/renderers/{claude-code, portable-prompt}.md` — render this spec into
  per-platform outputs
