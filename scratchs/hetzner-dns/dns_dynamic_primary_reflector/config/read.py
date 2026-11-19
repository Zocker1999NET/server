from __future__ import annotations

import json
from pathlib import Path
from typing import (
    Any,
)


# config return is Any by design
# to avoid expensive type checks on the config file, which *should* be sanitized
def read_config(path: Path | str) -> Any:
    "loads the JSON config file from the given path"
    with Path(path).open("r") as fh:
        return json.load(fh)
