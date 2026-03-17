"""HTTP API clients for 중기부 (odcloud) and 나라장터 (G2B).

Every fetch function accepts an ``httpx.Client`` as its first argument so
tests can inject a ``MockTransport`` without touching the network.
"""

from __future__ import annotations

from typing import Any

import httpx

from mobility_rfp_monitor.exceptions import ApiError
from mobility_rfp_monitor.models import Announcement, AnnouncementSource

# ---------------------------------------------------------------------------
# Base URLs
# ---------------------------------------------------------------------------
# 중소벤처기업부 기술개발과제정보 (odcloud)
MSS_BASE = "https://api.odcloud.kr/api/3044610/v1"
# 최신 데이터셋 (2025-07-16 기준)
MSS_LATEST_UDDI = "uddi:6463046e-cd88-45c0-9f8d-c76e296fd6cc"

# 나라장터 입찰공고정보서비스
G2B_BID_BASE = (
    "https://apis.data.go.kr/1230000/BidPublicInfoService"
    "/getBidPblancListInfoServc"
)

PER_PAGE = 100


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _extract_g2b_items(data: dict[str, Any]) -> list[dict[str, Any]]:
    """Extract the items list from a 공공데이터포털 JSON envelope."""
    body = data.get("response", data).get("body", {})
    items = body.get("items", [])
    if isinstance(items, dict):
        item_list = items.get("item", [])
        if isinstance(item_list, dict):
            return [item_list]
        return list(item_list)
    if isinstance(items, list):
        return items
    return []


def _mss_to_announcement(item: dict[str, Any]) -> Announcement:
    title = item.get("공고명", "")
    task_name = item.get("과제명", "")
    return Announcement(
        id=f"mss-{item.get('과제명', '')}-{item.get('사업년도', '')}",
        source=AnnouncementSource.MSS,
        title=title,
        description=task_name,
        url="",
        published_at=str(item.get("사업년도", "")),
        organization=item.get("전문기관명") or item.get("관리기관명") or "",
    )


def _g2b_bid_to_announcement(item: dict[str, Any]) -> Announcement:
    return Announcement(
        id=f"g2b_bid-{item.get('bidNtceNo', '')}-{item.get('bidNtceOrd', '00')}",
        source=AnnouncementSource.G2B_BID,
        title=item.get("bidNtceNm", ""),
        description=item.get("ntceInsttNm", ""),
        url=item.get("bidNtceDtlUrl", item.get("ntceDtlUrl", "")),
        published_at=item.get("bidNtceDt", ""),
        organization=item.get("ntceInsttNm", ""),
    )


def _raise_for_status(response: httpx.Response, source: str) -> None:
    if response.status_code != 200:
        raise ApiError(source, response.status_code, response.text[:200])


# ---------------------------------------------------------------------------
# Public fetch functions
# ---------------------------------------------------------------------------
def fetch_mss(
    http_client: httpx.Client,
    service_key: str,
    *,
    page: int = 1,
) -> list[Announcement]:
    """Fetch 중소벤처기업부 기술개발과제 from odcloud."""
    url = f"{MSS_BASE}/{MSS_LATEST_UDDI}"
    params: dict[str, Any] = {
        "serviceKey": service_key,
        "page": page,
        "perPage": PER_PAGE,
    }
    resp = http_client.get(url, params=params)
    _raise_for_status(resp, "mss")
    data = resp.json()
    items = data.get("data", [])
    return [_mss_to_announcement(i) for i in items]


def fetch_g2b_bids(
    http_client: httpx.Client,
    service_key: str,
    *,
    since: str,
    until: str,
) -> list[Announcement]:
    """Fetch 나라장터 입찰공고."""
    params: dict[str, Any] = {
        "serviceKey": service_key,
        "numOfRows": PER_PAGE,
        "pageNo": 1,
        "type": "json",
        "inqryBgnDt": since,
        "inqryEndDt": until,
    }
    resp = http_client.get(G2B_BID_BASE, params=params)
    _raise_for_status(resp, "g2b_bid")
    items = _extract_g2b_items(resp.json())
    return [_g2b_bid_to_announcement(i) for i in items]
