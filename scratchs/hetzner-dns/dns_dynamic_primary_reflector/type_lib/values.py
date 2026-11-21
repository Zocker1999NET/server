from __future__ import annotations

from collections.abc import (
    Mapping,
    Sequence,
)
from typing import (
    TypeAlias,
)

InfoVal: TypeAlias = (
    str | int | float | bool | Sequence["JsonVal"] | Mapping[str, "JsonVal"]
)
JsonVal: TypeAlias = InfoVal | None
