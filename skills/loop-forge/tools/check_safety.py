#!/usr/bin/env python3
"""check_safety.py — static safety check before stamping (the loop-forge assembler gate).

Just before the assembler (assembler.md) hands its neutral loop spec (spec.json) on to
the renderer (the stamp), this gate deterministically enforces what a non-developer
"doesn't even know they need" (the Ralph Wiggum failure: no inspector + soft completion
+ no stop switch):

  (1) jsonschema (loop_spec.schema.json) passes — 9 fields / enums / pattern / the
      registry cells with minLength>=1
  (2) registry.verifier non-empty — no inspector (maker != checker) -> no stamp
  (3) registry.hardstop  non-empty — no stop switch (budget/count/cooldown) -> no stamp
  (4) if archetype == "watch" or external_action == true, then
      registry.external_gate must be "dry_run" or "human_approval" (never "none")
      (an outbound send/post is gated by a dry-run preview or human approval first —
      the gate is enforced on the enum, not on prose, so it holds in any language)

Pass -> exit 0. Violation -> print the issue list to stderr and exit 2.

usage: check_safety.py <spec.json>
"""
from __future__ import annotations

import json
import pathlib
import sys

HERE = pathlib.Path(__file__).resolve().parent
SCHEMA_PATH = HERE / "loop_spec.schema.json"

# The outbound gate values that satisfy the external-action requirement. The Watch
# (or external_action) spec must carry one of these in registry.external_gate.
EXTERNAL_GATE_OK = ("dry_run", "human_approval")


def check(spec: dict) -> list[str]:
    """Inspect a loop spec and return a list of issue messages (empty = pass)."""
    issues: list[str] = []

    # (1) jsonschema passes
    try:
        import jsonschema
    except ImportError:
        return ["jsonschema is not installed. Run with `uv run --with jsonschema python check_safety.py <spec>`."]

    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    validator = jsonschema.Draft202012Validator(schema)
    for err in sorted(validator.iter_errors(spec), key=lambda e: list(e.path)):
        loc = "/".join(str(p) for p in err.path) or "(root)"
        issues.append(f"[schema] {loc}: {err.message}")
    if issues:
        # The schema is broken, so reading registry below would be unsafe; stop here
        # (this is already an exit-2 reason).
        return issues

    registry = spec.get("registry", {})

    # (2) verifier non-empty (the inspector = maker != checker)
    if not str(registry.get("verifier", "")).strip():
        issues.append("[verifier] registry.verifier is empty — no stamp without an inspector (maker != checker).")

    # (3) hardstop non-empty (the stop switch)
    if not str(registry.get("hardstop", "")).strip():
        issues.append("[hardstop] registry.hardstop is empty — no stamp without a stop switch (budget/count/cooldown).")

    # (4) watch / external_action -> external_gate must be dry_run or human_approval
    needs_external_gate = spec.get("archetype") == "watch" or spec.get("external_action") is True
    if needs_external_gate:
        gate = registry.get("external_gate")
        if gate not in EXTERNAL_GATE_OK:
            allowed = " / ".join(EXTERNAL_GATE_OK)
            issues.append(
                "[external-gate] this is a watch shape (or external_action=true), but "
                f"registry.external_gate is {gate!r}, not one of ({allowed}) — "
                "an outbound send/post must be gated by a dry-run preview or human approval first "
                "(outbound action = independent gate). No stamp."
            )

    return issues


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_safety.py <spec.json>", file=sys.stderr)
        return 2

    path = pathlib.Path(argv[1])
    try:
        spec = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        print(f"[load] file not found: {path}", file=sys.stderr)
        return 2
    except json.JSONDecodeError as exc:
        print(f"[load] JSON parse failed: {path}: {exc}", file=sys.stderr)
        return 2

    issues = check(spec)
    if issues:
        print("Safety check failed — stamping blocked:", file=sys.stderr)
        for issue in issues:
            print(f"  - {issue}", file=sys.stderr)
        return 2

    print(f"Safety check passed: {path.name} (archetype={spec.get('archetype')})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
