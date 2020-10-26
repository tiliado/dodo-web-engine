from __future__ import annotations
from pathlib import Path


def get_data_path(path: str) -> Path:
    result = Path(__file__).parent / "data"
    return result / path if path else result
