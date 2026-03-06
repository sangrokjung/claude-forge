"""CSV 읽기/검증 테스트."""

from pathlib import Path

import pytest

from email_automation.exceptions import (
    EmptyFileError,
    MissingColumnError,
)
from email_automation.reader import read_customers, validate_row


class TestReadCustomers:
    def test_reads_valid_csv(self, sample_csv: Path) -> None:
        customers = read_customers(sample_csv)
        assert len(customers) == 3

    def test_segments_parsed_correctly(self, sample_csv: Path) -> None:
        customers = read_customers(sample_csv)
        segments = {c.segment for c in customers}
        assert segments == {"enterprise", "startup", "individual"}

    def test_fields_parsed_correctly(self, sample_csv: Path) -> None:
        customers = read_customers(sample_csv)
        enterprise = next(c for c in customers if c.segment == "enterprise")
        assert enterprise.company == "테스트주식회사"
        assert enterprise.contact == "홍길동"
        assert enterprise.email == "gildong@test.com"

    def test_empty_file_raises(self, empty_csv: Path) -> None:
        with pytest.raises(EmptyFileError):
            read_customers(empty_csv)

    def test_header_only_raises(self, header_only_csv: Path) -> None:
        with pytest.raises(EmptyFileError):
            read_customers(header_only_csv)

    def test_missing_column_raises(self, missing_column_csv: Path) -> None:
        with pytest.raises(MissingColumnError) as exc_info:
            read_customers(missing_column_csv)
        assert "phone" in str(exc_info.value)
        assert "segment" in str(exc_info.value)
        assert "position" in str(exc_info.value)

    def test_file_not_found_raises(self, tmp_path: Path) -> None:
        with pytest.raises(FileNotFoundError):
            read_customers(tmp_path / "nonexistent.csv")

    def test_invalid_segment_raises(self, invalid_segment_csv: Path) -> None:
        with pytest.raises(ValueError, match="잘못된 세그먼트"):
            read_customers(invalid_segment_csv)

    def test_empty_field_raises(self, empty_field_csv: Path) -> None:
        with pytest.raises(ValueError, match="비어있습니다"):
            read_customers(empty_field_csv)

    def test_cp949_encoding(self, cp949_csv: Path) -> None:
        customers = read_customers(cp949_csv)
        assert len(customers) == 1
        assert customers[0].company == "한글회사"

    def test_customer_is_frozen(self, sample_csv: Path) -> None:
        customers = read_customers(sample_csv)
        with pytest.raises(AttributeError):
            customers[0].company = "변경시도"  # type: ignore[misc]


class TestValidateRow:
    def test_valid_row(self) -> None:
        row = {
            "company": "테스트",
            "contact": "홍길동",
            "email": "test@test.com",
            "segment": "enterprise",
            "phone": "010-0000-0000",
            "position": "CTO",
        }
        customer = validate_row(row, 2)
        assert customer.company == "테스트"

    def test_segment_case_insensitive(self) -> None:
        row = {
            "company": "테스트",
            "contact": "홍길동",
            "email": "test@test.com",
            "segment": "Enterprise",
            "phone": "010-0000-0000",
            "position": "CTO",
        }
        customer = validate_row(row, 2)
        assert customer.segment == "enterprise"

    def test_whitespace_stripped(self) -> None:
        row = {
            "company": "  테스트  ",
            "contact": " 홍길동 ",
            "email": "test@test.com",
            "segment": " startup ",
            "phone": "010-0000-0000",
            "position": "CTO",
        }
        customer = validate_row(row, 2)
        assert customer.company == "테스트"
        assert customer.contact == "홍길동"
        assert customer.segment == "startup"
