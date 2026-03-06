"""고객 데이터 모델."""

from dataclasses import dataclass

VALID_SEGMENTS = frozenset({"enterprise", "startup", "individual"})

REQUIRED_COLUMNS = frozenset(
    {"company", "contact", "email", "segment", "phone", "position"}
)


@dataclass(frozen=True)
class Customer:
    """고객 정보 (불변 데이터클래스)."""

    company: str
    contact: str
    email: str
    segment: str
    phone: str
    position: str
