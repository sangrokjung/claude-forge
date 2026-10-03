"""Tests for the chat_id gate — allowlist + bridge-owner enforcement."""

from __future__ import annotations

import os
import sys
import tempfile
import types
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

# `bot.py` imports `requests`; stub it so these tests don't need the dep
# installed on the test machine (it's an install-time dep for the bot
# itself, not for the test suite).
if "requests" not in sys.modules:
    fake_requests = types.ModuleType("requests")

    class _RequestException(Exception):
        pass

    fake_requests.RequestException = _RequestException  # type: ignore[attr-defined]
    fake_requests.get = lambda *a, **kw: None  # type: ignore[attr-defined]
    fake_requests.post = lambda *a, **kw: None  # type: ignore[attr-defined]
    sys.modules["requests"] = fake_requests

from bridge import BridgeManager  # noqa: E402


class BridgeOwnerTests(unittest.TestCase):
    """`bridge.inject` must refuse a sender that doesn't own the bridge.

    This is the defence against cross-chat injection: with two allowlisted
    ids A and B, B must not be able to type into the session that A opened.
    """

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.state_file = Path(self.tmp.name) / "bridge.json"
        self.sends: list[tuple[str, str]] = []

        def fake_send(chat_id: str, text: str) -> dict:
            self.sends.append((chat_id, text))
            return {"ok": True}

        self.bm = BridgeManager(send_message=fake_send, state_file=self.state_file)

    def tearDown(self) -> None:
        self.tmp.cleanup()

    def _start_bridge(self, owner: str = "AAAA") -> None:
        self.bm.start(
            session_uuid="deadbeef-0000-0000-0000-000000000000",
            jsonl_path=str(self.state_file.parent / "fake.jsonl"),
            tmux_target="session:0.0",
            chat_id=owner,
        )

    def test_inactive_bridge_refuses(self) -> None:
        ok, msg = self.bm.inject("hello", sender_chat_id="AAAA")
        self.assertFalse(ok)
        self.assertIn("no bridge active", msg)

    def test_non_owner_refused_before_tmux(self) -> None:
        """Owner mismatch must short-circuit before tmux lookup — so the
        test passes on CI boxes that don't have tmux installed."""
        self._start_bridge(owner="AAAA")
        ok, msg = self.bm.inject("hi", sender_chat_id="BBBB")
        self.assertFalse(ok)
        self.assertIn("not the bridge owner", msg)

    def test_owner_mismatch_type_coercion(self) -> None:
        """Numeric vs string chat ids must still compare correctly."""
        self._start_bridge(owner="12345")
        ok, msg = self.bm.inject("hi", sender_chat_id=99999)
        self.assertFalse(ok)
        self.assertIn("not the bridge owner", msg)
        # Matching integer form should NOT be rejected by the owner check
        # itself.  (It can still fail downstream on tmux-not-found — we
        # only assert the owner gate is open here.)
        ok, msg = self.bm.inject("hi", sender_chat_id=12345)
        if not ok:
            self.assertNotIn("not the bridge owner", msg)

    def test_no_sender_backward_compat(self) -> None:
        """Legacy callers that omit sender_chat_id should pass the gate —
        the owner check is enforced where the caller knows the sender."""
        self._start_bridge(owner="AAAA")
        with mock.patch("bridge.shutil.which", return_value=None):
            ok, msg = self.bm.inject("hi")  # no sender_chat_id
            self.assertFalse(ok)
            self.assertNotIn("not the bridge owner", msg)


class RedactTokenTests(unittest.TestCase):
    """`_redact` must strip the bot token out of arbitrary strings before
    they land in logs — the exception repr for a Telegram API URL
    otherwise leaks the token on every network blip."""

    def test_redacts_url_form(self) -> None:
        token = "1234567890:ABCDEF-abcdef"
        with mock.patch.dict(os.environ, {"TELEGRAM_BOT_TOKEN": token, "TELEGRAM_CHAT_IDS": "1"}):
            # Reimport under the patched env so the module-level BOT_TOKEN picks up the fake token.
            import importlib
            import bot
            importlib.reload(bot)
            try:
                msg = (
                    f"HTTPSConnectionPool(host='api.telegram.org', port=443): "
                    f"Max retries exceeded with url: /bot{token}/getUpdates"
                )
                out = bot._redact(msg)
                self.assertNotIn(token, out)
                self.assertIn("/bot<redacted>/", out)
            finally:
                # Reload with the test's own env so later tests see a clean module.
                importlib.reload(bot)

    def test_redacts_bare_token(self) -> None:
        token = "1234567890:ABCDEF-abcdef"
        with mock.patch.dict(os.environ, {"TELEGRAM_BOT_TOKEN": token, "TELEGRAM_CHAT_IDS": "1"}):
            import importlib
            import bot
            importlib.reload(bot)
            try:
                out = bot._redact(f"token was {token} in the clear")
                self.assertNotIn(token, out)
                self.assertIn("<redacted>", out)
            finally:
                importlib.reload(bot)

    def test_passthrough_without_token(self) -> None:
        with mock.patch.dict(os.environ, {"TELEGRAM_BOT_TOKEN": "", "TELEGRAM_CHAT_IDS": "1"}, clear=False):
            import importlib
            import bot
            importlib.reload(bot)
            try:
                out = bot._redact("no token here")
                self.assertEqual(out, "no token here")
            finally:
                importlib.reload(bot)


if __name__ == "__main__":
    unittest.main()
