"""Tests for Markdown escaping and Telegram message splitting."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from bridge import BridgeManager, MAX_TG_MESSAGE, escape_md  # noqa: E402


class EscapeMdTests(unittest.TestCase):
    def test_preserves_plain_text(self) -> None:
        self.assertEqual(escape_md("hello world"), "hello world")

    def test_escapes_each_special(self) -> None:
        # Backslash first — must be escaped first to avoid double-escaping
        # the escapes we introduce for the following chars.
        self.assertEqual(escape_md("\\"), "\\\\")
        self.assertEqual(escape_md("_"), "\\_")
        self.assertEqual(escape_md("*"), "\\*")
        self.assertEqual(escape_md("`"), "\\`")
        self.assertEqual(escape_md("["), "\\[")

    def test_escapes_combined(self) -> None:
        src = "`my_var` is *bold* [link](x)"
        out = escape_md(src)
        # Each special char must be preceded by a backslash exactly once.
        self.assertNotIn("`my_var`", out)
        self.assertIn("\\`my\\_var\\`", out)
        self.assertIn("\\*bold\\*", out)
        self.assertIn("\\[link", out)

    def test_backslash_runs_do_not_double_escape(self) -> None:
        # "\\" (two chars) → "\\\\" (four chars), not more
        self.assertEqual(escape_md("\\\\"), "\\\\\\\\")

    def test_empty(self) -> None:
        self.assertEqual(escape_md(""), "")


class SplitForTelegramTests(unittest.TestCase):
    def test_short_text_single_chunk(self) -> None:
        chunks = BridgeManager._split_for_telegram("hi")
        self.assertEqual(chunks, ["hi"])

    def test_exact_boundary_single_chunk(self) -> None:
        text = "x" * MAX_TG_MESSAGE
        chunks = BridgeManager._split_for_telegram(text)
        self.assertEqual(len(chunks), 1)
        self.assertEqual(chunks[0], text)

    def test_one_over_boundary_splits(self) -> None:
        text = "x" * (MAX_TG_MESSAGE + 1)
        chunks = BridgeManager._split_for_telegram(text)
        self.assertEqual(len(chunks), 2)
        # Each non-last chunk prefixed with pagination header
        self.assertTrue(chunks[0].startswith("_(1/2)_\n"))
        self.assertTrue(chunks[1].startswith("_(2/2)_\n"))

    def test_concat_recovers_original(self) -> None:
        text = "abcdefghij" * (MAX_TG_MESSAGE // 5)
        chunks = BridgeManager._split_for_telegram(text)
        # Strip the pagination header "_(N/M)_\n" from each chunk
        rebuilt = "".join(c.split("\n", 1)[1] for c in chunks)
        self.assertEqual(rebuilt, text)


if __name__ == "__main__":
    unittest.main()
