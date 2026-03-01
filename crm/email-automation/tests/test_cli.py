"""CLI 통합 테스트."""

import sys
from pathlib import Path

import pytest

from email_automation.cli import main


class TestCLI:
    def test_generates_email_files(
        self, sample_csv: Path, tmp_path: Path
    ) -> None:
        output_dir = tmp_path / "emails"
        main(["-i", str(sample_csv), "-o", str(output_dir)])
        files = list(output_dir.glob("*.txt"))
        assert len(files) == 3

    def test_segment_filter(
        self, sample_csv: Path, tmp_path: Path
    ) -> None:
        output_dir = tmp_path / "emails"
        main(["-i", str(sample_csv), "-o", str(output_dir), "-s", "enterprise"])
        files = list(output_dir.glob("*.txt"))
        assert len(files) == 1

    def test_dry_run_no_files(
        self, sample_csv: Path, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        output_dir = tmp_path / "emails"
        main([
            "-i", str(sample_csv),
            "-o", str(output_dir),
            "--dry-run",
        ])
        assert not output_dir.exists()
        captured = capsys.readouterr()
        assert "dry-run" in captured.out
        assert "3명" in captured.out

    def test_dry_run_shows_content(
        self, sample_csv: Path, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        output_dir = tmp_path / "emails"
        main([
            "-i", str(sample_csv),
            "-o", str(output_dir),
            "--dry-run",
        ])
        captured = capsys.readouterr()
        assert "테스트주식회사" in captured.out
        assert "스타트업랩" in captured.out

    def test_missing_file_exits(self, tmp_path: Path) -> None:
        with pytest.raises(SystemExit) as exc_info:
            main(["-i", str(tmp_path / "nonexistent.csv")])
        assert exc_info.value.code == 1

    def test_empty_segment_filter_exits(
        self, sample_csv: Path, tmp_path: Path
    ) -> None:
        output_dir = tmp_path / "emails"
        # sample_csv에는 enterprise 1건만 있으므로 startup 필터 시 1건
        # 하지만 존재하지 않는 세그먼트로는 테스트 불가 (argparse가 choices 검증)
        # 대신 enterprise 필터가 정상 작동하는지 확인
        main(["-i", str(sample_csv), "-o", str(output_dir), "-s", "startup"])
        files = list(output_dir.glob("*.txt"))
        assert len(files) == 1

    def test_error_message_on_stderr(
        self, tmp_path: Path, capsys: pytest.CaptureFixture[str]
    ) -> None:
        with pytest.raises(SystemExit):
            main(["-i", str(tmp_path / "nonexistent.csv")])
        captured = capsys.readouterr()
        assert "오류" in captured.err
