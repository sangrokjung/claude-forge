"""Phase 6: Email tests."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

from app.monitoring.dto import NormalizedNotice
from app.notify.email_smtp import build_alert_html, send_email


def _make_notice(title: str = "Test", url: str = "") -> NormalizedNotice:
    return NormalizedNotice(
        source="test",
        source_item_id="1",
        title=title,
        agency="TestOrg",
        summary="summary",
        url=url,
        deadline="",
        published_at="2026-01-01",
        fetched_at="2026-03-02T00:00:00",
        matched_keywords=frozenset({"자율주행"}),
    )


def test_build_html_contains_title():
    notices = [_make_notice("자율주행 사업 공고")]
    html = build_alert_html(notices)
    assert "자율주행 사업 공고" in html
    assert "1건" in html


def test_build_html_escapes_xss():
    notices = [_make_notice("<script>alert('xss')</script>")]
    html = build_alert_html(notices)
    assert "<script>" not in html
    assert "&lt;script&gt;" in html


def test_build_html_truncates():
    notices = [_make_notice(f"Notice {i}") for i in range(35)]
    html = build_alert_html(notices, max_items=30)
    assert "5건 생략" in html


@patch("app.notify.email_smtp.smtplib.SMTP")
def test_send_email_correct_recipients(mock_smtp_cls):
    mock_server = MagicMock()
    mock_smtp_cls.return_value.__enter__ = MagicMock(return_value=mock_server)
    mock_smtp_cls.return_value.__exit__ = MagicMock(return_value=False)

    send_email(
        smtp_host="localhost",
        smtp_port=587,
        smtp_user="from@test.com",
        smtp_password="pass",
        from_addr="from@test.com",
        to_addrs=["a@test.com", "b@test.com"],
        subject="Test",
        html="<html>hello</html>",
    )

    mock_server.sendmail.assert_called_once()
    call_args = mock_server.sendmail.call_args
    assert call_args[0][1] == ["a@test.com", "b@test.com"]


@patch("app.notify.email_smtp.smtplib.SMTP")
def test_send_email_raises_on_failure(mock_smtp_cls):
    import smtplib
    mock_server = MagicMock()
    mock_server.sendmail.side_effect = smtplib.SMTPException("fail")
    mock_smtp_cls.return_value.__enter__ = MagicMock(return_value=mock_server)
    mock_smtp_cls.return_value.__exit__ = MagicMock(return_value=False)

    import pytest
    with pytest.raises(RuntimeError, match="Email send failed"):
        send_email(
            smtp_host="localhost",
            smtp_port=587,
            smtp_user="from@test.com",
            smtp_password="pass",
            from_addr="from@test.com",
            to_addrs=["a@test.com"],
            subject="Test",
            html="<html>hello</html>",
        )
