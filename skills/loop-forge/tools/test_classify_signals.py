import json
import pathlib
import classify_signals as C
CORPUS = [json.loads(l) for l in pathlib.Path(__file__).with_name("corpus.jsonl").read_text().splitlines() if l.strip()]
def test_clear_cases_top1():
    clear = [c for c in CORPUS if not c["ambiguous"]]
    miss = [c["text"] for c in clear if C.classify(c["text"])["top"] != c["expected"]]
    assert not miss, f"misclassified: {miss}"        # 100% top-1 on the unambiguous corpus
def test_ambiguous_flagged():
    amb = [c for c in CORPUS if c["ambiguous"]]
    miss = [c["text"] for c in amb if not C.classify(c["text"])["ambiguous"]]
    assert not miss, f"ambiguous not flagged: {miss}"  # branch question fires on every conflict pair
