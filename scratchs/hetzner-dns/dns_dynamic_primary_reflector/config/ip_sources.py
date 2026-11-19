from __future__ import annotations

from collections.abc import (
    Iterable,
    Mapping,
)
from dataclasses import (
    dataclass,
)
import json
from typing import (
    Any,
    Callable,
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


def build_ip_sources(config: Any) -> SimpleSource[list[str]]:
    "builds the layered, consensus-based IP discovery pipeline from config"
    src_cfg = config["ip_sources"]

    def gen_multi_source(
        class_name: str,
        src_gen: Callable[..., InfoSource[str | None]],
    ) -> SimpleSource[str]:
        "builds a consensus source for one IP version from config"
        multi = MultiSource(
            sources=IPSourceIter(class_name, src_gen).gen_level_sources(src_cfg),
            minimum=1,
            max_uniform=3,
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
        src_cfg: Iterable[Iterable[Any]],
    ) -> list[list[InfoSource[str | None]]]:
        "builds the sources of every configured layer"
        return list(map(self.list_ip_sources, src_cfg))

    def list_ip_sources(self, src_list: Iterable[Any]) -> list[InfoSource[str | None]]:
        "builds the sources of one layer, dropping non-matching ones"
        return [s for s in map(self.gen_ip_source, src_list) if s is not None]

    def gen_ip_source(self, definition: Any) -> InfoSource[str | None] | None:
        "builds one source, None if its class does not match"
        return self.__gen_ip_source(self.__fill_definition(definition))

    def __gen_ip_source(
        self,
        definition: Mapping[str, Any],
    ) -> InfoSource[str | None] | None:
        "constructs the source from its filled definition"
        if definition.get("class", self.class_name) != self.class_name:
            return None
        args = {
            "url": definition["url"],
        }
        if "json_attr" in definition:
            json_attr = definition["json_attr"]
            args["ret_filter"] = lambda data: json.loads(data)[json_attr]
        return self.src_gen(**args)

    def __fill_definition(self, definition: Any) -> Mapping[str, Any]:
        "normalizes a plain URL definition into a full dict"
        return definition if isinstance(definition, dict) else {"url": definition}
