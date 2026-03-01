"""파일 출력 테스트."""

from pathlib import Path

from email_automation.models import Customer
from email_automation.writer import _sanitize_filename, write_emails


def _make_customers() -> list[Customer]:
    return [
        Customer(
            company="테스트주식회사",
            contact="홍길동",
            email="gildong@test.com",
            segment="enterprise",
            phone="02-0000-0000",
            position="CTO",
        ),
        Customer(
            company="스타트업랩",
            contact="이영수",
            email="ys@startup.kr",
            segment="startup",
            phone="010-1234-5678",
            position="CEO",
        ),
    ]


class TestWriteEmails:
    def test_creates_output_directory(self, tmp_path: Path) -> None:
        output_dir = tmp_path / "nested" / "output"
        write_emails(_make_customers(), output_dir)
        assert output_dir.exists()

    def test_creates_files_for_each_customer(self, tmp_path: Path) -> None:
        output_dir = tmp_path / "emails"
        created = write_emails(_make_customers(), output_dir)
        assert len(created) == 2

    def test_file_names_match_companies(self, tmp_path: Path) -> None:
        output_dir = tmp_path / "emails"
        created = write_emails(_make_customers(), output_dir)
        names = {p.name for p in created}
        assert "테스트주식회사.txt" in names
        assert "스타트업랩.txt" in names

    def test_file_content_is_utf8(self, tmp_path: Path) -> None:
        output_dir = tmp_path / "emails"
        created = write_emails(_make_customers(), output_dir)
        for path in created:
            content = path.read_text(encoding="utf-8")
            assert len(content) > 0

    def test_file_content_contains_company(self, tmp_path: Path) -> None:
        output_dir = tmp_path / "emails"
        write_emails(_make_customers(), output_dir)
        content = (output_dir / "테스트주식회사.txt").read_text(encoding="utf-8")
        assert "테스트주식회사" in content

    def test_returns_created_paths(self, tmp_path: Path) -> None:
        output_dir = tmp_path / "emails"
        created = write_emails(_make_customers(), output_dir)
        for path in created:
            assert path.exists()
            assert path.suffix == ".txt"

    def test_empty_list_creates_no_files(self, tmp_path: Path) -> None:
        output_dir = tmp_path / "emails"
        created = write_emails([], output_dir)
        assert created == []


class TestSanitizeFilename:
    def test_removes_special_characters(self) -> None:
        assert _sanitize_filename('test<>:"/\\|?*file') == "test_________file"

    def test_strips_dots_and_spaces(self) -> None:
        assert _sanitize_filename("  test. ") == "test"

    def test_empty_string_returns_unnamed(self) -> None:
        assert _sanitize_filename("...") == "unnamed"

    def test_normal_name_unchanged(self) -> None:
        assert _sanitize_filename("삼성전자") == "삼성전자"
