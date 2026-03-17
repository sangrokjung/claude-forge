"""렌더링 테스트."""

from email_automation.models import Customer
from email_automation.renderer import render_email


def _make_customer(segment: str = "enterprise") -> Customer:
    return Customer(
        company="테스트주식회사",
        contact="홍길동",
        email="gildong@test.com",
        segment=segment,
        phone="02-0000-0000",
        position="CTO",
    )


class TestRenderEmail:
    def test_enterprise_contains_company(self) -> None:
        result = render_email(_make_customer("enterprise"))
        assert "테스트주식회사" in result

    def test_enterprise_contains_contact(self) -> None:
        result = render_email(_make_customer("enterprise"))
        assert "홍길동" in result
        assert "CTO" in result

    def test_enterprise_formal_tone(self) -> None:
        result = render_email(_make_customer("enterprise"))
        assert "안녕하십니까" in result
        assert "엔터프라이즈" in result

    def test_startup_growth_message(self) -> None:
        result = render_email(_make_customer("startup"))
        assert "성장" in result
        assert "스케일링" in result

    def test_individual_personal_tone(self) -> None:
        result = render_email(_make_customer("individual"))
        assert "맞춤" in result
        assert "홍길동님" in result

    def test_all_segments_include_contact_info(self) -> None:
        for segment in ("enterprise", "startup", "individual"):
            result = render_email(_make_customer(segment))
            assert "gildong@test.com" in result
            assert "02-0000-0000" in result

    def test_all_segments_have_subject(self) -> None:
        for segment in ("enterprise", "startup", "individual"):
            result = render_email(_make_customer(segment))
            assert result.startswith("제목:")

    def test_render_returns_string(self) -> None:
        result = render_email(_make_customer())
        assert isinstance(result, str)
        assert len(result) > 0
