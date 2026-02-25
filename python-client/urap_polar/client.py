"""
HTTP client for the URAP Polar H10 iOS app API.
"""

from __future__ import annotations

from typing import Any, Dict, List

import requests

from .session import RecordingSession, RecordingSummary


def _normalize_base_url(base_url: str) -> str:
    return base_url.rstrip("/")


def list_recordings(base_url: str = "http://localhost:8080") -> List[RecordingSummary]:
    """Return a list of recording summaries from the iOS app."""
    url = _normalize_base_url(base_url) + "/recordings"
    response = requests.get(url, timeout=10)
    response.raise_for_status()
    data = response.json()
    return [RecordingSummary.from_dict(item) for item in data]


def get_recording(
    recording_id: str, base_url: str = "http://localhost:8080"
) -> RecordingSession:
    """Fetch a full recording session by ID. Returns a RecordingSession."""
    url = _normalize_base_url(base_url) + f"/recordings/{recording_id}"
    response = requests.get(url, timeout=30)
    response.raise_for_status()
    return RecordingSession(response.json())
