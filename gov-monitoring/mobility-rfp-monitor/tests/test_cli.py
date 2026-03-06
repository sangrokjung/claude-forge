"""Tests for cli.py — CLI entry point."""

from __future__ import annotations

import json
from pathlib import Path

import httpx
import pytest

from mobility_rfp_monitor.cli import main
from tests.conftest import load_fixture, make_mock_transport


def _full_transport() -> httpx.MockTransport:
    """Transport that returns fixture data for both API endpoints."""
    responses = {
        "odcloud.kr": (200, load_fixture("mss_response.json")),
        "BidPublicInfoService": (200, load_fixture("g2b_bid_response.json")),
    }
    return make_mock_transport(responses)


def _make_client() -> httpx.Client:
    return httpx.Client(transport=_full_transport())


class TestCliDryRun:
    def test_dry_run_outputs_results(
        self,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setenv("DATA_GO_KR_API_KEY", "test-key")
        state_file = str(tmp_path / "state.json")

        with _make_client() as client:
            exit_code = main(
                ["--dry-run", "--state-file", state_file],
                http_client=client,
            )
        assert exit_code == 0
        captured = capsys.readouterr()
        assert "matching announcement" in captured.out.lower() or "Summary:" in captured.out

    def test_state_file_created(
        self, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        monkeypatch.setenv("DATA_GO_KR_API_KEY", "test-key")
        state_file = tmp_path / "state.json"

        with _make_client() as client:
            main(
                ["--dry-run", "--state-file", str(state_file)],
                http_client=client,
            )
        assert state_file.exists()
        data = json.loads(state_file.read_text(encoding="utf-8"))
        assert "seen" in data


class TestCliMissingEnv:
    def test_missing_api_key(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.delenv("DATA_GO_KR_API_KEY", raising=False)
        exit_code = main(["--dry-run"])
        assert exit_code == 1
        captured = capsys.readouterr()
        assert "DATA_GO_KR_API_KEY" in captured.err

    def test_missing_slack_url(
        self,
        monkeypatch: pytest.MonkeyPatch,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setenv("DATA_GO_KR_API_KEY", "test-key")
        monkeypatch.delenv("SLACK_WEBHOOK_URL", raising=False)
        exit_code = main([])
        assert exit_code == 1
        captured = capsys.readouterr()
        assert "SLACK_WEBHOOK_URL" in captured.err


class TestCliSourceFilter:
    def test_mss_only(
        self,
        monkeypatch: pytest.MonkeyPatch,
        tmp_path: Path,
        capsys: pytest.CaptureFixture[str],
    ) -> None:
        monkeypatch.setenv("DATA_GO_KR_API_KEY", "test-key")
        state_file = str(tmp_path / "state.json")

        with _make_client() as client:
            exit_code = main(
                ["--dry-run", "--source", "mss", "--state-file", state_file],
                http_client=client,
            )
        assert exit_code == 0
        captured = capsys.readouterr()
        assert "Summary:" in captured.out
