"""공유 픽스처."""

import pytest
from pathlib import Path

SAMPLE_CSV = (
    "company,contact,email,segment,phone,position\n"
    "테스트주식회사,홍길동,gildong@test.com,enterprise,02-0000-0000,CTO\n"
    "스타트업랩,이영수,ys@startup.kr,startup,010-1234-5678,CEO\n"
    "박민수,박민수,ms@gmail.com,individual,010-9999-0000,프리랜서\n"
)


@pytest.fixture()
def sample_csv(tmp_path: Path) -> Path:
    """3건의 세그먼트별 샘플 CSV 파일을 생성."""
    csv_path = tmp_path / "customers.csv"
    csv_path.write_text(SAMPLE_CSV, encoding="utf-8")
    return csv_path


@pytest.fixture()
def empty_csv(tmp_path: Path) -> Path:
    """빈 CSV 파일을 생성."""
    csv_path = tmp_path / "empty.csv"
    csv_path.write_text("", encoding="utf-8")
    return csv_path


@pytest.fixture()
def header_only_csv(tmp_path: Path) -> Path:
    """헤더만 있는 CSV 파일을 생성."""
    csv_path = tmp_path / "header_only.csv"
    csv_path.write_text(
        "company,contact,email,segment,phone,position\n",
        encoding="utf-8",
    )
    return csv_path


@pytest.fixture()
def missing_column_csv(tmp_path: Path) -> Path:
    """필수 컬럼이 누락된 CSV 파일을 생성."""
    csv_path = tmp_path / "missing.csv"
    csv_path.write_text(
        "company,contact,email\n"
        "테스트,홍길동,test@test.com\n",
        encoding="utf-8",
    )
    return csv_path


@pytest.fixture()
def invalid_segment_csv(tmp_path: Path) -> Path:
    """잘못된 세그먼트 값이 포함된 CSV 파일을 생성."""
    csv_path = tmp_path / "invalid_segment.csv"
    csv_path.write_text(
        "company,contact,email,segment,phone,position\n"
        "테스트,홍길동,test@test.com,unknown,010-0000-0000,CTO\n",
        encoding="utf-8",
    )
    return csv_path


@pytest.fixture()
def empty_field_csv(tmp_path: Path) -> Path:
    """필수 필드가 빈 CSV 파일을 생성."""
    csv_path = tmp_path / "empty_field.csv"
    csv_path.write_text(
        "company,contact,email,segment,phone,position\n"
        "테스트,,test@test.com,enterprise,010-0000-0000,CTO\n",
        encoding="utf-8",
    )
    return csv_path


@pytest.fixture()
def cp949_csv(tmp_path: Path) -> Path:
    """CP949 인코딩 CSV 파일을 생성."""
    csv_path = tmp_path / "cp949.csv"
    content = (
        "company,contact,email,segment,phone,position\n"
        "한글회사,김한글,hangul@test.com,enterprise,02-0000-0000,대표\n"
    )
    csv_path.write_bytes(content.encode("cp949"))
    return csv_path
