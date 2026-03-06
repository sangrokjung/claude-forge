"""Email notification: HTML builder + SMTP sender."""

from __future__ import annotations

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from html import escape
from typing import Sequence

from app.monitoring.dto import NormalizedNotice

_SOURCE_LABELS = {
    "kstartup": "중기부 기술개발",
    "g2b_bid": "나라장터 입찰",
}


def build_alert_html(notices: Sequence[NormalizedNotice], max_items: int = 30) -> str:
    """Build HTML table for alert email. Pure function."""
    shown = list(notices[:max_items])
    remaining = len(notices) - len(shown)

    rows: list[str] = []
    for notice in shown:
        source_label = _SOURCE_LABELS.get(notice.source, notice.source)
        keywords = ", ".join(sorted(notice.matched_keywords)) if notice.matched_keywords else "-"
        title_cell = (
            f'<a href="{escape(notice.url)}">{escape(notice.title)}</a>'
            if notice.url
            else escape(notice.title)
        )
        rows.append(
            f"<tr>"
            f"<td>{title_cell}</td>"
            f"<td>{escape(source_label)}</td>"
            f"<td>{escape(notice.agency)}</td>"
            f"<td>{escape(notice.published_at)}</td>"
            f"<td>{escape(keywords)}</td>"
            f"</tr>"
        )

    footer = ""
    if remaining > 0:
        footer = f"<p><em>... 외 {remaining}건 생략</em></p>"

    return (
        "<html><body>"
        f"<h2>Mobility RFP Alert ({len(notices)}건)</h2>"
        "<table border='1' cellpadding='6' cellspacing='0' style='border-collapse:collapse;'>"
        "<thead><tr>"
        "<th>공고명</th><th>소스</th><th>기관</th><th>공고일</th><th>키워드</th>"
        "</tr></thead>"
        f"<tbody>{''.join(rows)}</tbody>"
        "</table>"
        f"{footer}"
        "</body></html>"
    )


def send_email(
    *,
    smtp_host: str,
    smtp_port: int,
    smtp_user: str,
    smtp_password: str,
    from_addr: str,
    to_addrs: list[str],
    subject: str,
    html: str,
) -> None:
    """Send HTML email via SMTP. Side effect."""
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = from_addr
    msg["To"] = ", ".join(to_addrs)
    msg.attach(MIMEText(html, "html", "utf-8"))

    try:
        with smtplib.SMTP(smtp_host, smtp_port, timeout=30) as server:
            server.starttls()
            server.login(smtp_user, smtp_password)
            server.sendmail(from_addr, to_addrs, msg.as_string())
    except smtplib.SMTPException as exc:
        raise RuntimeError(f"Email send failed: {exc}") from exc
