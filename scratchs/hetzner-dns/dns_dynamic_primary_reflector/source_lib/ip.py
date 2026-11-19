from __future__ import annotations

import re
import subprocess
from collections.abc import Callable
from dataclasses import (
    dataclass,
)
from enum import (
    Enum,
    auto,
)
from functools import cache, partial
from ipaddress import (
    IPv4Address,
    IPv6Address,
)
from typing import (
    assert_never,
)
from urllib.parse import urlparse

from ..action_lib import (
    SourceError,
)

from .utils import (
    InfoSourceImpl,
)


class _IpKind(Enum):
    "protocol version distinguisher for IP sources"

    IPv4 = auto()
    "query and expect an IPv4 address"
    IPv6 = auto()
    "query and expect an IPv6 address"


CURL_STATUS_TEXT_RE = re.compile(r"(?x)^CURL:(?P<status_code>\d{3})\n$")


@dataclass(
    eq=False,
    frozen=True,
    order=False,
    slots=True,
)
class _IpSource(InfoSourceImpl[str | None]):
    "retrieves the local public IP by querying a remote endpoint via curl"

    ip_kind: _IpKind
    "protocol version to request and expect"
    url: str
    "the remote endpoint to query"
    ret_filter: Callable[[str], str | None] = lambda x: x.strip()
    "any exception raised inside the filter is converged to a SourceError to ease implementation"

    def _retrieve(self) -> str | None:
        "requests the endpoint and normalizes its response"
        ret = self.__request()
        if ret is None:
            return None
        try:
            transformed = self.ret_filter(ret)
        except Exception as e:
            raise SourceError(
                self.source_name, f"error while parsing data: {ret!r}"
            ) from e
        return transformed if transformed is not None else None

    def __request(self) -> str | None:
        "downloads the URL with an IP-version-pinned curl invocation"
        # we need to pin requests to IPv4 / IPv6 for reliable IP measurements
        # - with (python) requests, this is nearly impossible
        # - so we’re using curl via subprocess here
        ret = subprocess.run(
            [
                "/usr/bin/env",
                "curl",
                self.__ip_curl_arg,
                "--location",
                "--max-time",
                "10",
                "--show-error",
                "--silent",
                "--write-out",
                r"%{stderr}CURL:%{response_code}\n",
                self.url,
            ],
            capture_output=True,
            check=False,
        )
        status_text = ret.stderr.decode()
        if ret.returncode != 0:
            # TODO differentiate errors for expectable ones
            raise Exception(f"(ret={ret.returncode}) {status_text}")
        status_parsed = CURL_STATUS_TEXT_RE.search(status_text)
        if status_parsed is None:
            raise ValueError(f"cannot parse curl write-out: {status_text!r}")
        status = status_parsed.groupdict()
        match int(status["status_code"]):
            case 200:
                return ret.stdout.decode()
            case 429:
                self._warn("server returned: 429 Too Many Requests")
                return None
            case x:
                raise SourceError(self.source_name, f"server returned: {x}")

    def normalize_ip(self, data: str) -> str | None:
        "expands a textual IP into its compressed canonical form"
        cls = self.__ip_class
        ip = cls(data)
        return ip.compressed

    @property
    def __ip_class(self) -> type[IPv4Address | IPv6Address]:
        "IPAddress subclass matching ip_kind"
        match self.ip_kind:
            case _IpKind.IPv4:
                return IPv4Address
            case _IpKind.IPv6:
                return IPv6Address
        assert_never(self.ip_kind)

    @property
    def __ip_curl_arg(self) -> str:
        "curl flag pinning the address family"
        match self.ip_kind:
            case _IpKind.IPv4:
                return "--ipv4"
            case _IpKind.IPv6:
                return "--ipv6"
        assert_never(self.ip_kind)

    @property
    def source_name(self) -> str:
        return _source_name(self.url)


# outsourced from _IpSource to avoid Ruff B019 https://docs.astral.sh/ruff/rules/cached-instance-method/
@cache
def _source_name(url: str) -> str:
    "extracts a source name from a URL for logging and error messages"
    return urlparse(url).netloc


IPv4Source = partial(_IpSource, _IpKind.IPv4)
IPv6Source = partial(_IpSource, _IpKind.IPv6)
