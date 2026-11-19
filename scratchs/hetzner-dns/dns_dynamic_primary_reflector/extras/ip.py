from __future__ import annotations

from collections.abc import (
    Sequence,
)
from dataclasses import (
    dataclass,
)
from ipaddress import (
    ip_address,
)

from ..action_lib import (
    SimpleSource,
)


@dataclass(
    frozen=True,
)
class IpCombinator(SimpleSource[list[str]]):
    "merges the IP sources of both protocol versions into one sorted list"

    ip_sources: Sequence[SimpleSource[str]]
    "the per-protocol-version sources to combine"

    @property
    def current_value(self) -> list[str]:
        # pass on everything we have, given sources should be cached with state if those are important
        ip_values = (ip_src.current_value for ip_src in self.ip_sources)
        ips_parsed = [ip_address(ip) for ip in ip_values if ip is not None]
        # normalize output
        ips_comp = (ip.compressed for ip in ips_parsed)
        return sorted(ips_comp)
