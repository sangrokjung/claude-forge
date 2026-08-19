#!/usr/bin/env python3
"""emdash_slop_check.py — detect em-dash (—/–) AI-tell interjections in Korean-dominant Markdown.

Flags two things:
  (1) body interjections  — mid-sentence " — aside" constructions
  (2) heading/title separators — "## A — B"

Both patterns are a known Korean AI-tell (see rules/korean-writing-quality.md §4):
en-dash/em-dash interjections read as a direct translation of English em-dash
prose and stand out as a machine-writing signature in Korean text specifically.

**Scoping gate (why this file exists as a separate, scoped checker):** the same
em-dash interjection pattern is completely normal, idiomatic English prose. A
checker with no language gate flags every English document that uses an
em-dash aside, which is pure noise for a bilingual/English-first codebase.
This checker computes a Hangul-character ratio for the whole file and skips
files that aren't substantially Korean — so an English README full of
em-dashes produces zero hits, by design, even though the same text would
match the raw regex. See `is_korean_dominant()`.

False-positive guards (kept from the pattern's underlying design):
table empty-value cells `| — |` (pipe-adjacent, excluded by the regex itself),
fenced code block contents, numeric ranges ("100-200px"), minus signs.

Usage:
  python3 emdash_slop_check.py file1.md [file2.md ...]
Output:
  on hits:  [Emdash Slop] file.md:LINE(kind): <excerpt>  (max 5 lines/file + summary)
  no hits:  no output
Exit code: 1 if any hit was found across all files, 0 if clean. The shipped
PostToolUse hook (hooks/emdash-slop-guard.sh) treats this as advisory
regardless of exit code — it always reports success to Claude Code and only
surfaces the findings as additionalContext, so a non-zero exit here never
blocks an edit. The non-zero exit exists for callers that run this checker
directly (CI, a pre-commit script, this file's own test fixtures).
"""
import re
import sys
import os

# Space-flanked em/en dash with a non-pipe, non-space character on both sides
# = an interjection or separator (pipe exclusion auto-skips table cells like `| — |`).
INTERJECT = re.compile(r'[^|\s] [—–] [^|\s]')

# Hangul syllable block vs. Latin letters: the ratio decides whether a file's
# content is "substantially Korean" enough for this checker to apply at all.
HANGUL_PATTERN = re.compile(r'[가-힣]')
LATIN_PATTERN = re.compile(r'[A-Za-z]')
KOREAN_RATIO_THRESHOLD = 0.15  # Hangul / (Hangul + Latin) letters, whole-file basis


def is_korean_dominant(text: str, threshold: float = KOREAN_RATIO_THRESHOLD) -> bool:
    """True if the file's letters are mostly Hangul rather than Latin.

    Deliberate tradeoff: this is a whole-file ratio, not per-line. A mostly-
    English doc with one Korean paragraph containing a real em-dash violation
    will not be flagged — that's the accepted cost of not firing on English
    docs at all (the false-positive class this checker exists to eliminate).
    """
    hangul = len(HANGUL_PATTERN.findall(text))
    latin = len(LATIN_PATTERN.findall(text))
    total = hangul + latin
    if total == 0:
        return False
    return (hangul / total) >= threshold


def check_file(path: str):
    try:
        with open(path, encoding='utf-8') as f:
            content = f.read()
    except (OSError, UnicodeDecodeError):
        return []

    if not is_korean_dominant(content):
        return []

    lines = content.splitlines()
    hits = []
    in_code = False
    for n, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped.startswith('```'):
            in_code = not in_code
            continue
        if in_code:
            continue
        if INTERJECT.search(line):
            kind = 'heading' if stripped.startswith('#') else 'body'
            hits.append((n, stripped, kind))
    return hits


def main(argv):
    total = 0
    kinds = set()
    for path in argv:
        if not os.path.isfile(path):
            continue
        hits = check_file(path)
        if not hits:
            continue
        total += len(hits)
        base = os.path.basename(path)
        for n, text, kind in hits[:5]:
            kinds.add(kind)
            print(f'[Emdash Slop] {base}:{n}({kind}): {text[:80]}')
        if len(hits) > 5:
            for _, _, kind in hits[5:]:
                kinds.add(kind)
            print(f'[Emdash Slop] {base}: ... and {len(hits) - 5} more')
    if total:
        rx = []
        if 'heading' in kinds:
            rx.append('heading/title separator -> colon (:) or line break')
        if 'body' in kinds:
            rx.append('body interjection -> split the sentence (comma, parentheses, or a separate line for a long aside)')
        print(f'[Emdash Slop] {total} total. Fix: {" / ".join(rx)} (rules/korean-writing-quality.md §4).')
    return 1 if total else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
