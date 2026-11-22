"""loading the JSON configuration file with an env variable overlay"""

from __future__ import annotations

import json
import os
from collections.abc import (
    Mapping,
)
from pathlib import Path
from typing import (
    Any,
)

from cattrs import (
    Converter,
)
from cattrs.gen import (
    make_dict_structure_fn,
)
from cattrs.gen import (
    override as cattrs_override,
)
from cattrs.preconf.json import (
    make_converter,
)

from .env import (
    split_env_config,
)
from .merge import (
    deep_merge,
)
from .types import (
    Config,
    IpSourceEntry,
    IpSourceSpec,
    LoggingConfig,
)

_STRICT_BOOLS = {
    "true": True,
    "false": False,
}
"the only string representations structurable into a bool"


def read_config(path: Path | str, env: Mapping[str, str] = os.environ) -> Config:
    "loads the JSON config file from the given path, overlayed by configuration env variables"
    with Path(path).open("r") as file_handle:
        file_values = json.load(file_handle)
    env_values = split_env_config(env)
    return __make_converter().structure(deep_merge(file_values, env_values), Config)


def __structure_bool_strict(value: Any, _type: Any) -> bool:
    "structures a bool strictly from the exact names true and false"
    if isinstance(value, bool):
        return value
    try:
        return _STRICT_BOOLS[value]
    except (KeyError, TypeError) as exc:
        raise ValueError(f"{value!r} is not a bool") from exc


def __make_converter() -> Converter:
    "creates the converter structuring merged config values into their typed classes"
    converter = make_converter()
    # structuring is strict: no unknown config keys
    ip_source_spec_hook = make_dict_structure_fn(
        IpSourceSpec,
        converter,
        ip_class=cattrs_override(rename="class"),
        _cattrs_forbid_extra_keys=True,
    )
    converter.register_structure_hook(IpSourceSpec, ip_source_spec_hook)
    converter.register_structure_hook(bool, __structure_bool_strict)
    converter.register_structure_hook(
        IpSourceEntry,
        __make_ip_source_entry_hook(ip_source_spec_hook),
    )
    converter.register_structure_hook(LoggingConfig, __make_logging_hook(converter))
    return converter


def __make_logging_hook(converter: Converter) -> Any:
    "creates the logging hook, a JSON null meaning the default config"

    def structure_logging(value: Any, _type: Any) -> Any:
        "structures null to the default logging config & dicts via the given converter"
        if value is None:
            return _type()
        # bypasses the LoggingConfig hook itself, avoiding recursion
        return make_dict_structure_fn(LoggingConfig, converter)(value, _type)

    return structure_logging


def __make_ip_source_entry_hook(
    ip_source_spec_hook: Any,
) -> Any:
    "creates the union hook structuring plain URLs and full source specs"

    def structure_ip_source_entry(value: Any, _type: Any) -> Any:
        if isinstance(value, str):
            return value
        return ip_source_spec_hook(value, IpSourceSpec)

    return structure_ip_source_entry
