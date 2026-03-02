"""httpx wrapper with timeout and retry."""

from __future__ import annotations

import httpx


def create_http_client(timeout: float = 20.0) -> httpx.Client:
    return httpx.Client(timeout=timeout)


def fetch_json(
    client: httpx.Client,
    url: str,
    *,
    method: str = "GET",
    params: dict | None = None,
) -> dict:
    if method.upper() == "GET":
        response = client.get(url, params=params)
    else:
        response = client.post(url, params=params)
    response.raise_for_status()
    return response.json()
