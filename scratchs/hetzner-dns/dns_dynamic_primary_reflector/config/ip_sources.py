from __future__ import annotations

import json
from collections.abc import (
    Callable,
    Iterable,
)
from dataclasses import (
    dataclass,
)
from typing import (
    Any,
)

from ..action_lib import (
    SimpleSource,
)
from ..extras import (
    IpCombinator,
)
from ..source_lib import (
    InfoSource,
    IPv4Source,
    IPv6Source,
    MultiSource,
    NotNoneSource,
    SourceUnpacker,
)
from .types import (
    Config,
    IpSourceEntry,
    IpSourceSpec,
)


def build_ip_sources(config: Config) -> SimpleSource[list[str]]:
    "builds the layered, consensus-based IP discovery pipeline from config"
    src_cfg = config.ip_sources

    def gen_multi_source(
        class_name: str,
        src_gen: Callable[..., InfoSource[str | None]],
    ) -> SimpleSource[str]:
        "builds a consensus source for one IP version from config"
        multi = MultiSource(
            sources=IPSourceIter(class_name, src_gen).gen_level_sources(src_cfg),
            minimum=config.ip_consensus_minimum,
            max_uniform=config.ip_consensus_max_uniform,
        )
        simple = SourceUnpacker(multi)
        not_none = NotNoneSource(simple)
        return not_none

    return IpCombinator(
        ip_sources=(
            gen_multi_source("ipv4", IPv4Source),
            gen_multi_source("ipv6", IPv6Source),
        ),
    )


@dataclass(frozen=True)
class IPSourceIter:
    "creates configured IP sources from raw config entries"

    class_name: str
    "IP version class a source must state (or default to)"
    src_gen: Callable[..., InfoSource[str | None]]
    "source constructor for the matching class"

    def gen_level_sources(
        self,
        src_cfg: Iterable[Iterable[IpSourceEntry]],
    ) -> list[list[InfoSource[str | None]]]:
        "builds the sources of every configured layer"
        return list(map(self.list_ip_sources, src_cfg))

    def list_ip_sources(
        self,
        src_list: Iterable[IpSourceEntry],
    ) -> list[InfoSource[str | None]]:
        "builds the sources of one layer, dropping non-matching ones"
        return [s for s in map(self.gen_ip_source, src_list) if s is not None]

    def gen_ip_source(self, definition: IpSourceEntry) -> InfoSource[str | None] | None:
        "builds one source, None if its class does not match"
        spec = (
            definition
            if isinstance(definition, IpSourceSpec)
            else IpSourceSpec(url=definition)
        )
        return self.__gen_ip_source(spec)

    def __gen_ip_source(
        self,
        spec: IpSourceSpec,
    ) -> InfoSource[str | None] | None:
        "constructs the source from its specification"
        if not (spec.ip_class is None or spec.ip_class == self.class_name):
            return None
        src_kwargs: dict[str, Any] = {
            "url": spec.url,
        }
        if spec.json_attr is not None:
            json_attr = spec.json_attr
            src_kwargs["ret_filter"] = lambda data: json.loads(data)[json_attr]
        return self.src_gen(**src_kwargs)
