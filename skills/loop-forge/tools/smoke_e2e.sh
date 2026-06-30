#!/usr/bin/env bash
# smoke_e2e.sh — loop-forge end-to-end + full safety-device smoke
#
# One script that covers the end-to-end + the stamped-output smoke + the static
# safety check: entry → assemble → stamp (the batch golden output shape) + all 5
# archetype golden specs passing check_safety (verifying the auto-injected safety)
# + a Watch negative case with the external gate removed.
#
# Four bundles:
#   (a) safety sweep   — all 5 examples/*/spec.json pass check_safety (exit 0)
#   (b) negative case  — a Watch spec with external_gate dropped to "none" → exit 2
#   (c) unit regression — pytest (classifier + safety) all PASS
#   (d) stamped output — grep the batch golden (claude-command / portable-prompt)
#
# If anything fails, print the failure list at the end and exit 1; all-pass → exit 0.
#
# jsonschema is injected via uv `--with` (no new external dependency).
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

PASS=0
FAIL=0
FAILS=()

ok() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
ng() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); FAILS+=("$1"); }

# Run check_safety.py and echo its exit code on stdout.
run_safety() {
  uv run --with jsonschema python check_safety.py "$1" >/dev/null 2>&1
  echo $?
}

# grep for a fixed string ($2) in a file ($1); -F fixed · -- stops option parsing
# so $ARGUMENTS, parens, and ≠ are safe.
grep_has() { # $1=file $2=pattern $3=label
  if grep -qF -- "$2" "$1"; then ok "$3"; else ng "$3 (missing: '$2' in $1)"; fi
}

ARCH=(batch pipeline refine watch explore)

echo "== (a) safety sweep — all 5 archetype spec.json pass check_safety exit 0 =="
for a in "${ARCH[@]}"; do
  spec="examples/$a/spec.json"
  if [[ ! -f "$spec" ]]; then
    ng "($a) spec.json missing — $spec"
    continue
  fi
  rc="$(run_safety "$spec")"
  if [[ "$rc" == "0" ]]; then ok "($a) check_safety exit 0"; else ng "($a) check_safety exit $rc (expected 0)"; fi
done

echo "== (b) negative case — Watch with external_gate dropped → check_safety exit 2 =="
TMP="$HERE/_tmp_watch_no_gate.json"
python3 - "$HERE/examples/watch/spec.json" "$TMP" <<'PY'
import json, sys
src, dst = sys.argv[1], sys.argv[2]
spec = json.load(open(src, encoding="utf-8"))
# Drop the outbound gate: set external_gate to "none" (the enum the static check rejects for Watch).
spec["registry"]["external_gate"] = "none"
json.dump(spec, open(dst, "w", encoding="utf-8"), ensure_ascii=False)
PY
rc="$(run_safety "$TMP")"
if [[ "$rc" == "2" ]]; then
  ok "Watch without an external gate → exit 2 (the gate really blocks it)"
else
  ng "Watch without an external gate but exit $rc (expected 2) — the gate failed to block"
fi
rm -f "$TMP"

echo "== (c) unit regression — pytest (classifier + safety) PASS =="
PYLOG="$HERE/_tmp_pytest.log"
if uv run --with jsonschema pytest test_classify_signals.py test_check_safety.py -q >"$PYLOG" 2>&1; then
  ok "pytest test_classify_signals.py test_check_safety.py"
else
  ng "pytest failed (log below)"
  tail -20 "$PYLOG"
fi
rm -f "$PYLOG"

echo "== (d) stamped-output shape — grep the batch golden (claude-command / portable-prompt) =="
CC="examples/batch/claude-command.md"
PP="examples/batch/portable-prompt.md"
if [[ ! -f "$CC" ]]; then ng "claude-command.md missing — $CC"; fi
if [[ ! -f "$PP" ]]; then ng "portable-prompt.md missing — $PP"; fi
if [[ -f "$CC" ]]; then
  grep_has "$CC" '$ARGUMENTS' "claude-command: \$ARGUMENTS"
  grep_has "$CC" '## Verifier (auto)' "claude-command: ## Verifier (auto)"
  grep_has "$CC" '## Hardstop' "claude-command: ## Hardstop"
fi
if [[ -f "$PP" ]]; then
  grep_has "$PP" '## Verifier (auto)' "portable-prompt: ## Verifier (auto)"
  grep_has "$PP" '## Hardstop' "portable-prompt: ## Hardstop"
fi
# Equivalence — the Claude Code and Portable Prompt outputs carry the same
# verifier/hardstop text (only the invocation differs).
if [[ -f "$CC" && -f "$PP" ]]; then
  grep_has "$CC" 'maker ≠ checker' "claude-command: verifier text (maker ≠ checker)"
  grep_has "$PP" 'maker ≠ checker' "portable-prompt: verifier text (maker ≠ checker) identical"
  grep_has "$CC" 'max_items 100 budget cap' "claude-command: hardstop text"
  grep_has "$PP" 'max_items 100 budget cap' "portable-prompt: hardstop text identical"
fi

echo
echo "==== smoke summary: PASS=$PASS  FAIL=$FAIL ===="
if [[ "$FAIL" -gt 0 ]]; then
  echo "failed items:"
  for f in "${FAILS[@]}"; do echo "  - $f"; done
  exit 1
fi
echo "all smoke checks passed (exit 0)."
exit 0
