"""Tests for channels.email — SMTP email channel with HTML formatting."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest

from mobility_rfp_monitor.channels.email import EmailChannel, _build_html
from mobility_rfp_monitor.exceptions import EmailNotificationError
from mobility_rfp_monitor.models import Announcement, AnnouncementSource


def _make_ann(id_: str, title: str, *, url: str | None = None) -> Announcement:
    return Announcement(
        id=id_,
        source=AnnouncementSource.MSS,
        title=title,
        description="desc",
        url=url if url is not None else f"https://example.com/{id_}",
        published_at="2026-03-01",
        organization="Org",
        matched_keywords=frozenset({"모빌리티"}),
    )


class TestBuildHtml:
    def test_contains_title(self) -> None:
        html = _build_html([_make_ann("h1", "테스트 공고")], max_items=30)
        assert "테스트 공고" in html
        assert "1건" in html

    def test_link_in_html(self) -> None:
        html = _build_html([_make_ann("h2", "링크 공고", url="https://g2b.go.kr/123")], max_items=30)
        assert 'href="https://g2b.go.kr/123"' in html

    def test_no_url_no_link(self) -> None:
        ann = Announcement(
            id="h3",
            source=AnnouncementSource.MSS,
            title="URL 없는 공고",
            description="desc",
            url="",
            published_at="2026-03-01",
            organization="Org",
            matched_keywords=frozenset({"모빌리티"}),
        )
        html = _build_html([ann], max_items=30)
        assert "URL 없는 공고" in html
        assert "href" not in html

    def test_truncation_footer(self) -> None:
        anns = [_make_ann(f"t-{i}", f"공고 {i}") for i in range(10)]
        html = _build_html(anns, max_items=3)
        assert "7건 생략" in html

    def test_no_truncation_footer(self) -> None:
        anns = [_make_ann(f"nt-{i}", f"공고 {i}") for i in range(3)]
        html = _build_html(anns, max_items=30)
        assert "생략" not in html

    def test_html_escaping(self) -> None:
        ann = _make_ann("esc", '<script>alert("xss")</script>')
        html = _build_html([ann], max_items=30)
        assert "<script>" not in html
        assert "&lt;script&gt;" in html


class TestEmailChannel:
    def _make_channel(self) -> EmailChannel:
        return EmailChannel(
            smtp_host="smtp.example.com",
            smtp_port=587,
            smtp_user="user@example.com",
            smtp_password="password",
            from_addr="user@example.com",
            to_addrs=["recipient@example.com"],
        )

    def test_channel_name(self) -> None:
        ch = self._make_channel()
        assert ch.channel_name == "email"

    def test_send_empty(self) -> None:
        ch = self._make_channel()
        assert ch.send([]) == 0

    @patch("mobility_rfp_monitor.channels.email.smtplib.SMTP")
    def test_send_success(self, mock_smtp_class: MagicMock) -> None:
        mock_server = MagicMock()
        mock_smtp_class.return_value.__enter__ = MagicMock(return_value=mock_server)
        mock_smtp_class.return_value.__exit__ = MagicMock(return_value=False)

        ch = self._make_channel()
        count = ch.send([_make_ann("e1", "Email Test")])

        assert count == 1
        mock_server.starttls.assert_called_once()
        mock_server.login.assert_called_once_with("user@example.com", "password")
        mock_server.sendmail.assert_called_once()

    @patch("mobility_rfp_monitor.channels.email.smtplib.SMTP")
    def test_send_smtp_error(self, mock_smtp_class: MagicMock) -> None:
        import smtplib

        mock_server = MagicMock()
        mock_server.login.side_effect = smtplib.SMTPAuthenticationError(535, b"auth failed")
        mock_smtp_class.return_value.__enter__ = MagicMock(return_value=mock_server)
        mock_smtp_class.return_value.__exit__ = MagicMock(return_value=False)

        ch = self._make_channel()
        with pytest.raises(EmailNotificationError):
            ch.send([_make_ann("e2", "Fail Test")])

    @patch("mobility_rfp_monitor.channels.email.smtplib.SMTP")
    def test_no_starttls_when_disabled(self, mock_smtp_class: MagicMock) -> None:
        mock_server = MagicMock()
        mock_smtp_class.return_value.__enter__ = MagicMock(return_value=mock_server)
        mock_smtp_class.return_value.__exit__ = MagicMock(return_value=False)

        ch = EmailChannel(
            smtp_host="smtp.example.com",
            smtp_port=25,
            smtp_user="user@example.com",
            smtp_password="password",
            from_addr="user@example.com",
            to_addrs=["recipient@example.com"],
            use_starttls=False,
        )
        ch.send([_make_ann("e3", "No TLS")])
        mock_server.starttls.assert_not_called()
