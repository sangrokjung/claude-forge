#!/usr/bin/env python3
"""Situation sentence -> loop-shape lightweight signal scorer.

From a one-line situation a non-developer typed, count deterministic keyword
signals and produce a **first-pass hint** among the 5 shapes
(batch/pipeline/refine/watch/explore). The final call belongs to the LLM in
SKILL.md, using the semantic signal table and the branch questions in
`classifier.md`.

- `SIGNALS` mirrors the "(1) Diagnostic signals" section of each
  `references/archetypes/<shape>.md` (and the §1 table in `classifier.md`).
  Matching is substring, case-insensitive.
- The scorer ships an **English** keyword set. For input in another language it
  simply returns no signal (`top: null`), and the LLM classifies from meaning
  (language-agnostic). Classification never depends on surface keywords.
- ambiguous: when the top two shapes tie (both >= 1), that's the signal to fire a
  branch question. Known confusion pairs (batch<->watch, pipeline<->refine,
  batch<->explore) are reported in their canonical order.

CLI: `python classify_signals.py "summarize 100 shop reviews into 3 lines each"`
"""
from __future__ import annotations

# Mirror of the "(1) Diagnostic signals" section in the 5 archetype catalogs
# (order and content match each catalog and the classifier.md §1 table).
# Matching is case-insensitive substring; ultra-common bare tokens are kept
# narrow on purpose so they don't over-match unrelated phrasing.
SIGNALS: dict[str, list[str]] = {
    "batch": [
        "100 of them", "process n items", "run through all n",
        "all of them", "summarize them all", "every single one",
        "each one", "one by one", "for every item",
        "this list", "the whole list", "the entire set",
        "in bulk", "all at once", "go through them",
    ],
    "pipeline": [
        "then", "after that", "use that to",
        "in order", "one after another", "step by step",
        "do a then b then c", "a -> b -> c", "a → b → c",
        "run it through", "pass it through", "hand it off to",
        "first do x then later do y",
    ],
    "refine": [
        "make it better", "raise the quality", "more polished",
        "refine it", "polish it", "touch it up",
        "draft and fix", "fix it up", "iterate on it",
        "make it nicer", "revise it a few times",
    ],
    "watch": [
        "every time one arrives", "whenever a new one comes in",
        "when something new shows up", "when it pops up",
        "when it appears", "when it happens", "when detected",
        "when it's caught", "when it matches", "when a condition is met",
        "automatically when x", "auto-notify me",
        "send me an alert", "check and let me know",
    ],
    "explore": [
        "several", "a few options", "make a few",
        "ideas", "candidates", "compare options",
        "pick one", "the best", "the strongest", "the top choice",
        "make n and pick the best", "generate and choose",
        "choices", "among several versions",
    ],
}

# The catalog-defined confusion pairs (the branch-question targets). When
# reporting a pair, normalize to this direction.
CONFLICT_PAIRS: list[tuple[str, str]] = [
    ("batch", "watch"),
    ("pipeline", "refine"),
    ("batch", "explore"),
]


def _score(text: str) -> dict[str, int]:
    """Count the matched signal keywords per shape (1 per keyword)."""
    t = (text or "").lower()
    return {arch: sum(1 for kw in kws if kw in t) for arch, kws in SIGNALS.items()}


def _order_pair(a: str, b: str) -> tuple[str, str]:
    """A confusion pair in its catalog order; otherwise (top, second)."""
    s = {a, b}
    for x, y in CONFLICT_PAIRS:
        if {x, y} == s:
            return (x, y)
    return (a, b)


def classify(text: str) -> dict:
    """Situation sentence -> first-pass hint.

    Returns: {"ranked":[(archetype,score),...], "top":archetype|None,
              "ambiguous":bool, "pair":(a,b)|None}
    - top: the single dominant shape. None when ambiguous or no signal.
    - ambiguous: the top two shapes tie (both >= 1) -> fire a branch question.
    """
    scores = _score(text)
    # Descending by score; ties broken alphabetically by shape name (deterministic).
    ranked = sorted(scores.items(), key=lambda kv: (-kv[1], kv[0]))
    top_arch, top_score = ranked[0]
    second_arch, second_score = ranked[1]

    if top_score == 0:  # no signal at all -> the LLM decides directly
        return {"ranked": ranked, "top": None, "ambiguous": False, "pair": None}

    # Top-two tie (both >= 1) -> ambiguous -> branch question
    if second_score >= 1 and (top_score - second_score) < 1:
        pair = _order_pair(top_arch, second_arch)
        return {"ranked": ranked, "top": None, "ambiguous": True, "pair": pair}

    return {"ranked": ranked, "top": top_arch, "ambiguous": False, "pair": None}


def _main(argv: list[str]) -> int:
    import json
    text = " ".join(argv).strip()
    if not text:
        print('usage: python classify_signals.py "<situation sentence>"', flush=True)
        return 1
    r = classify(text)
    out = {
        "ranked": [[a, s] for a, s in r["ranked"]],
        "top": r["top"],
        "ambiguous": r["ambiguous"],
        "pair": list(r["pair"]) if r["pair"] else None,
    }
    print(json.dumps(out, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    import sys
    raise SystemExit(_main(sys.argv[1:]))
