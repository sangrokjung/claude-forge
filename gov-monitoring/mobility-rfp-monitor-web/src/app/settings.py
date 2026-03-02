"""Application settings via pydantic-settings (env vars / .env file)."""

from __future__ import annotations

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}

    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    jwt_expire_hours: int = 72

    database_url: str = "sqlite:///./rfp_monitor.db"

    smtp_host: str = "smtp.gmail.com"
    smtp_port: int = 587
    smtp_user: str = ""
    smtp_pass: str = ""

    config_path: str = "config.yaml"
    data_go_kr_api_key: str = ""
