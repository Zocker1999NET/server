"""typed configuration structure of the JSON config file"""

from __future__ import annotations

import attrs


@attrs.define(frozen=True, kw_only=True)
class IpSourceSpec:
    "one configured IP source in full dict form"

    ip_class: str | None = None
    "IP version class the source reports, None defaults to the surrounding class"
    url: str
    "URL to request the public IP from"
    json_attr: str | None = None
    "JSON attribute of the response containing the IP, None for plain text responses"


IpSourceEntry = str | IpSourceSpec
"one configured IP source, plain URL or full dict form"


@attrs.define(frozen=True, kw_only=True)
class NtfyConfig:
    "remote logging configuration of one ntfy topic"

    url: str
    "URL of the ntfy topic to publish log records to"


@attrs.define(frozen=True, kw_only=True)
class LoggingConfig:
    "logging configuration"

    ntfy: NtfyConfig | None = None
    "remote ntfy logging, None to disable"


@attrs.define(frozen=True, kw_only=True)
class Config:
    "the full application configuration"

    hetzner_api_key: str
    "API key of the Hetzner DNS zone management API"
    hetzner_domains: list[str] = attrs.Factory(list)
    "DNS zone names to reflect the discovered public IPs on"
    ip_sources: list[list[IpSourceEntry]] = attrs.Factory(list)
    "layered public IP discovery sources, layers are consulted in order"
    ip_consensus_minimum: int = 1
    "number of uniform & successful answers required for consensus to be acceptable"
    ip_consensus_max_uniform: int | None = 3
    "accept one IP version’s consensus immediately once this many uniform answers arrived, None to always query all sources"
    logging: LoggingConfig = attrs.Factory(LoggingConfig)
    "logging configuration"
