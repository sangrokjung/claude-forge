"""메일 파일 출력."""

import re
from pathlib import Path

from email_automation.models import Customer
from email_automation.renderer import render_email


def _sanitize_filename(name: str) -> str:
    """파일명에 사용할 수 없는 문자를 제거."""
    sanitized = re.sub(r'[<>:"/\\|?*]', "_", name)
    sanitized = sanitized.strip(". ")
    return sanitized or "unnamed"


def write_emails(
    customers: list[Customer], output_dir: Path
) -> list[Path]:
    """고객 리스트를 기반으로 세그먼트별 메일 파일을 생성."""
    output_dir.mkdir(parents=True, exist_ok=True)

    created: list[Path] = []
    for customer in customers:
        content = render_email(customer)
        filename = f"{_sanitize_filename(customer.company)}.txt"
        filepath = output_dir / filename
        filepath.write_text(content, encoding="utf-8")
        created.append(filepath)

    return created
