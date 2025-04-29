from __future__ import annotations

from collections.abc import (
    Sequence,
)
from ipaddress import (
    IPv6Interface,
    IPv6Network,
)
import re
from typing import (
    NewType,
    TypeGuard,
)


MACAddress = NewType("MACAddress", str)
"""format: aabbccddeeff (lower-case, without separators)"""
NftProtocol = NewType("NftProtocol", str)  # e.g. tcp, udp, …
Port = NewType("Port", int)
NftTable = NewType("NftTable", str)


def to_mac(mac_str: str) -> MACAddress:
    eui48 = re.sub(r"[.:_-]", "", mac_str.lower())
    if not is_mac(eui48):
        raise ValueError(f"invalid MAC address / EUI48: {mac_str}")
    return MACAddress(eui48)


def is_mac(mac_str: str) -> TypeGuard[MACAddress]:
    return re.match(r"^[0-9a-f]{12}$", mac_str) != None


def to_port(port_str: str | int) -> Port:
    try:
        port = int(port_str)
    except ValueError as exc:
        raise ValueError(f"invalid port number: {port_str}") from exc
    if not is_port(port):
        raise ValueError(f"invalid port number: {port_str}")
    return Port(port)


def is_port(port: int) -> TypeGuard[Port]:
    return 0 < port < 65536


def slaac_eui48(prefix: IPv6Network, eui48: MACAddress) -> IPv6Interface:
    if prefix.prefixlen > 64:
        raise ValueError(
            f"a SLAAC IPv6 address requires a prefix with CIDR of at least /64, got {prefix}"
        )
    eui64 = eui48[0:6] + "fffe" + eui48[6:]
    modified = hex(int(eui64[0:2], 16) ^ 2)[2:].zfill(2) + eui64[2:]
    euil = int(modified, 16)
    return IPv6Interface(f"{prefix[euil].compressed}/{prefix.prefixlen}")


IPv6_ULA_NET = IPv6Network("fc00::/7")  # because ip.is_private is wrong


def gen_set_def(
    set_type: str,
    name: str,
    data_type: str,
    flags: str | None = None,
    elements: Sequence[str] = tuple(),
) -> str:
    return "\n".join(
        line
        for line in (
            f"{set_type} {name} " + "{",
            f"    type {data_type}",
            f"    flags {flags}" if flags is not None else None,
            (
                "    elements = { " + ", ".join(elements) + " }"
                if len(elements) > 0
                else None
            ),
            "}",
        )
        if line is not None
    )
