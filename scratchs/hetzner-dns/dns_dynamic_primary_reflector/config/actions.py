from __future__ import annotations

from typing import (
    Any,
)

from ..hetzner import (
    HetznerPrimaryAction,
)

from ..action_lib import (
    Action,
)


def build_actions(config: Any) -> list[Action[list[str]]]:
    "builds the configured update actions targeting all configured domains"
    # hetzner, simplified config variant
    domains = config.get("hetzner_domains", [])
    api_key = config.get("hetzner_api_key")
    return [
        HetznerPrimaryAction.from_api_key(
            api_key=api_key,
            zone_name=name,
        )
        for name in domains
    ]
