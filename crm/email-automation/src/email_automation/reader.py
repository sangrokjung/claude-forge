"""CSV 파일 읽기 + 검증."""

import csv
from pathlib import Path

from email_automation.exceptions import (
    EmptyFileError,
    EncodingError,
    MissingColumnError,
)
from email_automation.models import REQUIRED_COLUMNS, VALID_SEGMENTS, Customer


def _read_with_encoding(path: Path) -> str:
    """utf-8 → cp949 → latin-1 순서로 인코딩을 시도하여 파일 내용을 반환."""
    encodings = ("utf-8", "cp949", "latin-1")
    for encoding in encodings:
        try:
            return path.read_text(encoding=encoding)
        except (UnicodeDecodeError, UnicodeError):
            continue
    raise EncodingError(str(path))


def _validate_columns(header: list[str], path: Path) -> None:
    """필수 컬럼 존재 여부 검증."""
    missing = sorted(REQUIRED_COLUMNS - set(header))
    if missing:
        raise MissingColumnError(missing)


def validate_row(row: dict[str, str], line_num: int) -> Customer:
    """행 데이터를 검증하고 Customer 객체로 변환."""
    for col in REQUIRED_COLUMNS:
        value = row.get(col, "").strip()
        if not value:
            raise ValueError(
                f"{line_num}번째 행: '{col}' 값이 비어있습니다"
            )

    segment = row["segment"].strip().lower()
    if segment not in VALID_SEGMENTS:
        raise ValueError(
            f"{line_num}번째 행: 잘못된 세그먼트 '{segment}' "
            f"(허용: {', '.join(sorted(VALID_SEGMENTS))})"
        )

    return Customer(
        company=row["company"].strip(),
        contact=row["contact"].strip(),
        email=row["email"].strip(),
        segment=segment,
        phone=row["phone"].strip(),
        position=row["position"].strip(),
    )


def read_customers(path: Path) -> list[Customer]:
    """CSV 파일을 읽어 Customer 리스트로 반환."""
    if not path.exists():
        raise FileNotFoundError(f"파일을 찾을 수 없습니다: {path}")

    content = _read_with_encoding(path)
    if not content.strip():
        raise EmptyFileError(str(path))

    lines = content.splitlines()
    reader = csv.DictReader(lines)

    if reader.fieldnames is None:
        raise EmptyFileError(str(path))

    _validate_columns(list(reader.fieldnames), path)

    rows = list(reader)
    if not rows:
        raise EmptyFileError(str(path))

    customers: list[Customer] = []
    errors: list[str] = []

    for i, row in enumerate(rows, start=2):
        try:
            customers.append(validate_row(row, i))
        except ValueError as e:
            errors.append(str(e))

    if errors:
        raise ValueError(
            f"데이터 검증 실패 ({len(errors)}건):\n" + "\n".join(errors)
        )

    return customers
