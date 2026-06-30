import json
import subprocess
import sys
import pathlib
import copy
HERE = pathlib.Path(__file__).parent
GOOD = json.loads((HERE/"examples/batch/spec.json").read_text())
def run(spec):  # run check_safety.py as a subprocess
    p = HERE/"_tmp_spec.json"; p.write_text(json.dumps(spec, ensure_ascii=False))
    r = subprocess.run([sys.executable, str(HERE/"check_safety.py"), str(p)], capture_output=True, text=True)
    p.unlink(); return r.returncode
def test_good_batch_passes(): assert run(GOOD) == 0
def test_missing_hardstop_rejected():
    bad = copy.deepcopy(GOOD); bad["registry"]["hardstop"] = ""
    assert run(bad) == 2
def test_watch_without_external_gate_rejected():
    w = copy.deepcopy(GOOD); w["archetype"] = "watch"; w["external_action"] = True
    w["registry"]["verifier"] = "look at the result once more"   # no outbound gate
    w["registry"]["external_gate"] = "none"                      # outbound gate absent
    assert run(w) == 2
