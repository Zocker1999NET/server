from __future__ import annotations

from ..action_lib import (
    Action,
)
from ..hetzner import (
    HetznerPrimaryAction,
)
from .types import (
    Config,
)


def build_actions(config: Config) -> list[Action[list[str]]]:
    "builds the configured update actions targeting all configured domains"
    return [
        HetznerPrimaryAction.from_api_key(
            api_key=config.hetzner_api_key,
            zone_name=name,
        )
        for name in config.hetzner_domains
    ]
