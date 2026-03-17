"""Email (SMTP) notification channel — HTML formatted announcements."""

from __future__ import annotations

import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from html import escape
from typing import Sequence

from mobility_rfp_monitor.exceptions import EmailNotificationError
from mobility_rfp_monitor.models import Announcement

_SOURCE_LABELS = {
    "mss": "중기부 기술개발",
    "g2b_bid": "나라장터 입찰",
}


def _build_html(announcements: Sequence[Announcement], max_items: int) -> str:
    shown = list(announcements[:max_items])
    remaining = len(announcements) - len(shown)

    rows: list[str] = []
    for ann in shown:
        source_label = _SOURCE_LABELS.get(ann.source.value, ann.source.value)
        keywords = ", ".join(sorted(ann.matched_keywords)) if ann.matched_keywords else "-"
        title_cell = (
            f'<a href="{escape(ann.url)}">{escape(ann.title)}</a>'
            if ann.url
            else escape(ann.title)
        )
        rows.append(
            f"<tr>"
            f"<td>{title_cell}</td>"
            f"<td>{escape(source_label)}</td>"
            f"<td>{escape(ann.organization)}</td>"
            f"<td>{escape(ann.published_at)}</td>"
            f"<td>{escape(keywords)}</td>"
            f"</tr>"
        )

    footer = ""
    if remaining > 0:
        footer = f"<p><em>... 외 {remaining}건 생략</em></p>"

    return (
        "<html><body>"
        f"<h2>Mobility RFP Alert ({len(announcements)}건)</h2>"
        "<table border='1' cellpadding='6' cellspacing='0' style='border-collapse:collapse;'>"
        "<thead><tr>"
        "<th>공고명</th><th>소스</th><th>기관</th><th>공고일</th><th>키워드</th>"
        "</tr></thead>"
        f"<tbody>{''.join(rows)}</tbody>"
        "</table>"
        f"{footer}"
        "</body></html>"
    )


class EmailChannel:
    """SMTP email notification channel."""

    def __init__(
        self,
        *,
        smtp_host: str,
        smtp_port: int,
        smtp_user: str,
        smtp_password: str,
        from_addr: str,
        to_addrs: list[str],
        subject_prefix: str = "[모빌리티 공고 모니터]",
        use_starttls: bool = True,
        max_items_per_email: int = 30,
    ) -> None:
        self._smtp_host = smtp_host
        self._smtp_port = smtp_port
        self._smtp_user = smtp_user
        self._smtp_password = smtp_password
        self._from_addr = from_addr
        self._to_addrs = to_addrs
        self._subject_prefix = subject_prefix
        self._use_starttls = use_starttls
        self._max_items = max_items_per_email

    @property
    def channel_name(self) -> str:
        return "email"

    def send(self, announcements: Sequence[Announcement]) -> int:
        if not announcements:
            return 0

        msg = MIMEMultipart("alternative")
        msg["Subject"] = f"{self._subject_prefix} {len(announcements)}건 신규 공고"
        msg["From"] = self._from_addr
        msg["To"] = ", ".join(self._to_addrs)

        html = _build_html(announcements, self._max_items)
        msg.attach(MIMEText(html, "html", "utf-8"))

        try:
            with smtplib.SMTP(self._smtp_host, self._smtp_port, timeout=30) as server:
                if self._use_starttls:
                    server.starttls()
                server.login(self._smtp_user, self._smtp_password)
                server.sendmail(self._from_addr, self._to_addrs, msg.as_string())
        except smtplib.SMTPException as exc:
            raise EmailNotificationError(str(exc)) from exc

        return len(announcements)
