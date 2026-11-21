"""recursive merging of two JSON-like configuration sources"""

from __future__ import annotations

from typing import (
    Any,
)


def deep_merge(base: Any, overlay: Any) -> Any:
    "merges two JSON-like values, preferring overlay leaves on conflicts"
    merged: Any
    if isinstance(base, dict) and isinstance(overlay, dict):
        merged = dict(base)
        for key, value in overlay.items():
            merged[key] = deep_merge(merged[key], value) if key in merged else value
    elif isinstance(base, list) and isinstance(overlay, list):
        merged = list(base)
        for index, value in enumerate(overlay):
            if index < len(merged):
                merged[index] = deep_merge(merged[index], value)
            else:
                merged.append(value)
    else:
        merged = overlay
    return merged
