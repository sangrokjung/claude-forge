"""세그먼트별 메일 렌더링."""

from email_automation.models import Customer
from email_automation.templates import TEMPLATES


def render_email(customer: Customer) -> str:
    """Customer 정보를 기반으로 세그먼트별 메일 문구를 생성."""
    template = TEMPLATES[customer.segment]
    return template.substitute(
        company=customer.company,
        contact=customer.contact,
        email=customer.email,
        phone=customer.phone,
        position=customer.position,
    )
