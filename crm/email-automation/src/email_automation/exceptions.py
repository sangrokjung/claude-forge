"""커스텀 예외 정의."""


class EmptyFileError(Exception):
    """CSV 파일이 비어있거나 헤더만 존재할 때 발생."""

    def __init__(self, path: str) -> None:
        super().__init__(f"파일이 비어있습니다: {path}")
        self.path = path


class MissingColumnError(Exception):
    """필수 컬럼이 누락되었을 때 발생."""

    def __init__(self, missing: list[str]) -> None:
        columns = ", ".join(missing)
        super().__init__(f"필수 컬럼이 누락되었습니다: {columns}")
        self.missing = missing


class EncodingError(Exception):
    """지원하는 인코딩으로 파일을 읽을 수 없을 때 발생."""

    def __init__(self, path: str) -> None:
        super().__init__(f"파일 인코딩을 인식할 수 없습니다: {path}")
        self.path = path
