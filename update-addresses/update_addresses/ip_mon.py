"infrastructure to monitor IPs on network interfaces on Linux systems (with the cli tool 'ip')"

from __future__ import annotations

from collections.abc import (
    Mapping,
    Sequence,
)
from datetime import (
    datetime,
    timedelta,
)
from enum import (
    Enum,
    Flag,
    auto,
)
from ipaddress import (
    IPv4Network,
    IPv6Network,
    IPv4Interface,
    IPv6Interface,
)
from logging import getLogger
import re
import subprocess
from typing import (
    NewType,
    NoReturn,
    TypeAlias,
)

from attrs import (
    define,
)

from .handlers import UpdateHandler


logger = getLogger(__name__)


IPNetwork: TypeAlias = IPv4Network | IPv6Network
IPInterface: TypeAlias = IPv4Interface | IPv6Interface
IfName = NewType("IfName", str)

# parses output of "ip -o address" / "ip -o monitor address"
IP_MON_PATTERN = re.compile(
    r"""(?x)^
        (?P<deleted>[Dd]eleted\s+)?
        (?P<ifindex>\d+):\s+
        (?P<ifname>\S+)\s+
        (?P<type>inet6?)\s+
        (?P<ip>\S+)\s+
        #(?:metric\s+\S+\s+)?  # sometimes possible
        #(?:brd\s+\S+\s+)?  # broadcast IP on inet
        (?:\S+\s+\S+\s+)* # abstracted irrelevant attributes
        (?:scope\s+(?P<scope>\S+)\s+)
        (?P<flags>(?:(\S+)\s)*)  # (single spaces required for parser below to work correctly)
        (?:\S+)?  # random interface name repetition on inet
        [\\]\s+
        valid_lft\s+(
            (?P<valid_lft_sec>\d+)sec
            |
            (?P<valid_lft_forever>forever)
        )
        \s+
        preferred_lft\s+(
            (?P<preferred_lft_sec>\d+)sec
            |
            (?P<preferred_lft_forever>forever)
        )
        \s*
    $"""
)


class IpFlag(Flag):
    dynamic = auto()
    mngtmpaddr = auto()
    noprefixroute = auto()
    temporary = auto()
    tentiative = auto()

    @staticmethod
    def parse_str(flags_str: Sequence[str], ignore_unknown: bool = True) -> IpFlag:
        flags = IpFlag(0)
        for flag in flags_str:
            flag = flag.lower()
            member = IpFlag.__members__.get(flag)
            if member is not None:
                flags |= member
            elif not ignore_unknown:
                raise Exception(f"Unrecognized IpFlag: {flag}")
        return flags


@define(
    frozen=True,
    kw_only=True,
)
class IpAddressUpdate:
    deleted: bool
    ifindex: int
    ifname: IfName
    ip: IPInterface
    scope: str
    flags: IpFlag
    valid_until: datetime
    preferred_until: datetime

    @classmethod
    def parse_line(cls, line: str) -> IpAddressUpdate:
        m = IP_MON_PATTERN.search(line)
        if not m:
            raise Exception(f"Could not parse ip monitor output: {line!r}")
        grp = m.groupdict()
        ip_type: type[IPInterface] = (
            IPv6Interface if grp["type"] == "inet6" else IPv4Interface
        )
        try:
            ip = ip_type(grp["ip"])
        except ValueError as e:
            raise Exception(
                f"Could not parse ip monitor output, invalid IP: {grp['ip']!r}"
            ) from e
        flags = IpFlag.parse_str(grp["flags"].strip().split(" "))
        return IpAddressUpdate(
            deleted=grp["deleted"] != None,
            ifindex=int(grp["ifindex"]),
            ifname=IfName(grp["ifname"]),
            ip=ip,
            scope=grp["scope"],
            flags=flags,
            valid_until=cls.__parse_lifetime(grp, "valid_lft"),
            preferred_until=cls.__parse_lifetime(grp, "preferred_lft"),
        )

    @staticmethod
    def __parse_lifetime(grp: Mapping[str, str | None], name: str) -> datetime:
        if grp[f"{name}_forever"] != None:
            return datetime.now() + timedelta(days=30)
        sec = grp[f"{name}_sec"]
        if sec is None:
            raise ValueError(
                "IP address update parse error: expected regex group for seconds != None (bug in code)"
            )
        return datetime.now() + timedelta(seconds=int(sec))


class SpecialIpUpdate(Enum):
    FLUSH_RULES = auto()


IpUpdate: TypeAlias = IpAddressUpdate | SpecialIpUpdate


@define(
    frozen=True,
    kw_only=True,
)
class IpMonitor:
    ip_cmd: list[str]
    handler: UpdateHandler[IpUpdate]

    def kickoff(self) -> None:
        self.handler.update(SpecialIpUpdate.FLUSH_RULES)
        res = subprocess.run(
            self.ip_cmd + ["-o", "address", "show"],
            check=True,
            stdout=subprocess.PIPE,
            text=True,
        )
        for line in res.stdout.splitlines(keepends=False):
            line = line.rstrip()
            if not line:
                continue
            self.__pass_update(line)

    def monitor(self) -> NoReturn:
        proc = subprocess.Popen(
            self.ip_cmd + ["-o", "monitor", "address"],
            stdout=subprocess.PIPE,
            text=True,
        )
        # initial kickoff (AFTER starting monitoring, to not miss any update)
        logger.info("kickoff IP monitoring with current data")
        self.kickoff()
        logger.info("start regular monitoring")
        while True:
            rc = proc.poll()
            if rc != None:
                # flush stdout for easier debugging
                logger.error("Last stdout of monitor process:")
                logger.error(proc.stdout.read())  # type: ignore[union-attr]
                raise Exception(f"Monitor process crashed with returncode {rc}")
            line = proc.stdout.readline().rstrip()  # type: ignore[union-attr]
            if not line:
                continue
            logger.info("IP change detected")
            self.__pass_update(line)

    def __pass_update(self, line: str) -> None:
        update = IpAddressUpdate.parse_line(line)
        logger.debug(f"pass IP update: {update!r}")
        self.handler.update(update)
