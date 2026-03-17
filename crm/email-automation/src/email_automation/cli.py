"""CLI 진입점."""

import argparse
import sys
from pathlib import Path

from email_automation.exceptions import (
    EmptyFileError,
    EncodingError,
    MissingColumnError,
)
from email_automation.reader import read_customers
from email_automation.renderer import render_email
from email_automation.writer import write_emails


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="CSV 고객 데이터를 읽어 세그먼트별 맞춤 안내메일을 생성합니다.",
    )
    parser.add_argument(
        "-i", "--input",
        type=Path,
        default=Path("data/customers.csv"),
        help="CSV 파일 경로 (기본: data/customers.csv)",
    )
    parser.add_argument(
        "-o", "--output",
        type=Path,
        default=Path("out/emails"),
        help="출력 디렉토리 (기본: out/emails)",
    )
    parser.add_argument(
        "-s", "--segment",
        choices=["enterprise", "startup", "individual"],
        help="특정 세그먼트만 필터링",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="실제 파일 생성 없이 미리보기",
    )
    return parser


def main(argv: list[str] | None = None) -> None:
    parser = _build_parser()
    args = parser.parse_args(argv)

    try:
        customers = read_customers(args.input)
    except (
        FileNotFoundError,
        EmptyFileError,
        MissingColumnError,
        EncodingError,
        ValueError,
    ) as e:
        print(f"오류: {e}", file=sys.stderr)
        sys.exit(1)

    if args.segment:
        customers = [c for c in customers if c.segment == args.segment]

    if not customers:
        print("해당 조건에 맞는 고객이 없습니다.", file=sys.stderr)
        sys.exit(1)

    if args.dry_run:
        print(f"[dry-run] {len(customers)}명의 고객 메일을 생성합니다.\n")
        for customer in customers:
            print(f"--- {customer.company} ({customer.segment}) ---")
            print(render_email(customer))
            print()
        return

    created = write_emails(customers, args.output)
    print(f"{len(created)}개의 메일 파일이 생성되었습니다: {args.output}")
    for path in created:
        print(f"  - {path.name}")


if __name__ == "__main__":
    main()
