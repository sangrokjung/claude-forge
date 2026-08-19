#!/usr/bin/env python3
"""Regression fixtures for scripts/emdash_slop_check.py.

Plain asserts, no pytest dependency. Run with: python3 scripts/tests/test_emdash_check.py
"""
import subprocess
import sys
import tempfile
import pathlib

CHECK = pathlib.Path(__file__).resolve().parents[2] / "scripts" / "emdash_slop_check.py"


def run(text):
    f = tempfile.NamedTemporaryFile("w", suffix=".md", delete=False, encoding="utf-8")
    f.write(text)
    f.close()
    p = subprocess.run([sys.executable, str(CHECK), f.name], capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


# Case 1: Korean-dominant body interjection must be flagged.
rc, out = run("본문에 줄표 삽입구 — 이런 형태 — 가 있는 글이다. 한국어 문장이 이어진다.\n")
assert rc != 0 and "body" in out, f"body interjection must be flagged: {out}"

# Case 2: Korean-dominant heading separator must be flagged.
rc, out = run("## 제목 — 부제 구분자\n한국어 본문 문장이 이어진다.\n")
assert rc != 0 and "heading" in out, f"heading separator must be flagged: {out}"

# Case 3: table-cell dash and numeric ranges must not be treated as interjections
# (still Korean-dominant text, so this proves the exclusion regex, not the language gate).
rc, out = run("| — |\n한국어 문장에서 수치 범위 100-200px는 대상 아님을 설명한다.\n")
assert rc == 0, f"table-cell dash and numeric ranges must pass: {out}"

# Case 4 (scoping gate): an English document with the same em-dash interjection
# pattern must NOT fire — this is the false-positive class the Hangul-ratio
# gate exists to eliminate (see emdash_slop_check.py's is_korean_dominant()).
rc, out = run("This is a body sentence — with an interjection — right here in English prose.\n")
assert rc == 0 and out == "", f"English doc with em-dashes must not fire: {out}"

# Case 5 (per-line gate): a Korean-dominant file whose em-dash sits on an
# ENGLISH line must not fire. Korean rule docs quote the English patterns they
# ban, and a translated guide keeps English headings — an em-dash aside inside
# an English sentence is correct English prose whatever the file's language is.
rc, out = run(
    "이 문서는 한국어 규칙 문서이고 본문 대부분이 한국어 문장으로 이어진다.\n"
    "한국어 문장이 하나 더 있어야 파일 전체 비율이 한국어로 잡힌다.\n"
    "This quoted English line has an interjection — like this one — inside it.\n"
)
assert rc == 0 and out == "", f"English line in a Korean file must not fire: {out}"

# Case 6 (per-line gate, the other direction): the same file with the em-dash on
# a KOREAN line must still fire. The per-line gate is a language filter, not an
# escape hatch that silences the check inside bilingual documents.
rc, out = run(
    "이 문서는 한국어 규칙 문서이고 본문 대부분이 한국어 문장으로 이어진다.\n"
    "This quoted English line is perfectly clean and carries no interjection.\n"
    "한국어 본문에 줄표 삽입구 — 이런 형태 — 가 남아 있으면 반드시 잡아야 한다.\n"
)
assert rc != 0 and "body" in out, f"Korean line in a bilingual file must fire: {out}"

print("OK: 6 cases")
