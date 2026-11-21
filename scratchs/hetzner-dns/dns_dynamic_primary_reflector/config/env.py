"""env variable based configuration overlay, split into JSON-like structures"""

from __future__ import annotations

from collections.abc import (
    Mapping,
)
from typing import (
    Any,
)

ENV_CONFIG_PREFIX = "DDPR:"
"prefix of env variables providing configuration overlays"

ENV_VALUE_SEPARATOR = ":"
"separator structuring the names of configuration env variables"


def split_env_config(
    env: Mapping[str, str],
    prefix: str = ENV_CONFIG_PREFIX,
) -> dict[str, Any]:
    "structures all prefixed env variables into a JSON-like dict of raw string values"
    root: dict[str, Any] = {}
    for name, value in env.items():
        if not name.startswith(prefix):
            continue
        path = name[len(prefix) :]
        if not path:
            raise ValueError(
                f"env variable {name!r} is not structured: missing path after {prefix!r}"
            )
        __insert(root, path.split(ENV_VALUE_SEPARATOR), value, name)
    unexpanded = __unexpand_int_dicts(root)
    assert isinstance(unexpanded, dict), "root of the structured env config is a dict"
    return unexpanded


def __insert(
    root: dict[str, Any],
    path: list[str],
    value: str,
    name: str,
) -> None:
    "inserts one raw string value at the structured path"
    if any(not segment for segment in path):
        raise ValueError(
            f"env variable {name!r} contains an empty path segment between separators"
        )
    node: Any = root
    for segment in path[:-1]:
        if not isinstance(node, dict):
            raise TypeError(f"env variable {name!r} descends into a scalar value")
        node = node.setdefault(__segment_key(segment), {})
    if not isinstance(node, dict):
        raise TypeError(f"env variable {name!r} overwrites a scalar value")
    node[__segment_key(path[-1])] = value


def __segment_key(segment: str) -> int | str:
    "maps one path segment to its dict key, digits become list indices"
    return int(segment) if segment.isdigit() else segment


def __unexpand_int_dicts(node: Any) -> Any:
    "turns digit-keyed dicts into lists, failing on holes or mixed keys"
    if not isinstance(node, dict):
        return node
    materialized = {key: __unexpand_int_dicts(value) for key, value in node.items()}
    int_keys = [key for key in materialized if isinstance(key, int)]
    if not int_keys:
        return materialized
    if len(int_keys) != len(materialized):
        raise ValueError("mixed digit and non-digit keys cannot form a list index")
    indices = sorted(int_keys)
    if indices != list(range(len(indices))):
        raise ValueError(f"list indices leave a hole: {indices!r}")
    return [materialized[i] for i in indices]
