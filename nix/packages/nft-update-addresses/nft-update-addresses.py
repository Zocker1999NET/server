#!/usr/bin/env python3

from __future__ import annotations

from abc import (
    ABC,
    abstractmethod,
)
import argparse
from collections import defaultdict
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
from functools import cached_property
import io
from ipaddress import (
    IPv4Interface,
    IPv6Interface,
    IPv6Network,
)
from itertools import chain
import json
import logging
from logging.handlers import SysLogHandler
import os
from pathlib import Path
import re
import shlex
from string import Template
import subprocess
import threading
from threading import (
    RLock,
    Timer,
)
import traceback
from typing import (
    Any,
    Iterable,
    Literal,
    NewType,
    NoReturn,
    Protocol,
    TypeAlias,
    TypeGuard,
    TypeVar,
    Union,
    cast,
)

from attrs import (
    define,
    field,
)
from systemd import daemon  # type: ignore[import-untyped]
from systemd.journal import JournalHandler  # type: ignore[import-untyped]


logger = logging.getLogger(__name__)


def raise_and_exit(args: Any) -> None:
    Timer(0.01, os._exit, args=(1,)).start()
    logger.error(repr(args.exc_value))
    logger.error(
        "\n".join(traceback.format_tb(args.exc_traceback))
        if args.exc_traceback != None
        else "traceback from thread got lost!"
    )
    raise args.exc_value or Exception(f"{args.exc_type} (exception details got lost)")


# ensure exceptions in any thread brings the program down
# important for proper error detection via tests & in random cases in real world

threading.excepthook = raise_and_exit


JsonVal: TypeAlias = Union["JsonObj", "JsonList", str, int, bool]
JsonList: TypeAlias = Sequence[JsonVal]
JsonObj: TypeAlias = Mapping[str, JsonVal]

T = TypeVar("T", contravariant=True)

MACAddress = NewType("MACAddress", str)
"""format: aabbccddeeff (lower-case, without separators)"""
IPInterface: TypeAlias = IPv4Interface | IPv6Interface
NftProtocol = NewType("NftProtocol", str)  # e.g. tcp, udp, …
Port = NewType("Port", int)
IfName = NewType("IfName", str)
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


class UpdateHandler(Protocol[T]):
    def update(self, data: T) -> None:
        ...

    def update_stack(self, data: Sequence[T]) -> None:
        ...


class UpdateStackHandler(UpdateHandler[T], ABC):
    def update(self, data: T) -> None:
        return self._update_stack((data,))

    def update_stack(self, data: Sequence[T]) -> None:
        if len(data) <= 0:
            logger.warning(
                f"[bug, please report upstream] received empty data in update_stack. Traceback:\n{''.join(traceback.format_stack())}"
            )
            return
        return self._update_stack(data)

    @abstractmethod
    def _update_stack(self, data: Sequence[T]) -> None:
        ...


class IgnoreHandler(UpdateStackHandler[object]):
    def _update_stack(self, data: Sequence[object]) -> None:
        return


@define(
    kw_only=True,
    slots=False,
)
class UpdateBurstHandler(UpdateStackHandler[T]):
    burst_interval: float
    handler: Sequence[UpdateHandler[T]]
    __lock: RLock = field(factory=RLock)
    __updates: list[T] = field(factory=list)
    __timer: Timer | None = None

    def _update_stack(self, data: Sequence[T]) -> None:
        with self.__lock:
            self.__updates.extend(data)
            self.__refresh_timer()

    def __refresh_timer(self) -> None:
        with self.__lock:
            if self.__timer is not None:
                # try to cancel
                # not a problem if timer already elapsed but before processing really started
                # because due to using locks when accessing updates
                self.__timer.cancel()
            self.__timer = Timer(
                interval=self.burst_interval,
                function=self.__process_updates,
            )
            self.__timer.start()

    def __process_updates(self) -> None:
        with self.__lock:
            self.__timer = None
            if not self.__updates:
                return
            updates = self.__updates
            self.__updates = []
        for handler in self.handler:
            handler.update_stack(updates)


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


IPv6_ULA_NET = IPv6Network("fc00::/7")  # because ip.is_private is wrong

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


def kickoff_ip(
    ip_cmd: list[str],
    handler: UpdateHandler[IpAddressUpdate],
) -> None:
    res = subprocess.run(
        ip_cmd + ["-o", "address", "show"],
        check=True,
        stdout=subprocess.PIPE,
        text=True,
    )
    for line in res.stdout.splitlines(keepends=False):
        line = line.rstrip()
        if line == "":
            continue
        update = IpAddressUpdate.parse_line(line)
        logger.debug(f"pass IP update: {update!r}")
        handler.update(update)


def monitor_ip(
    ip_cmd: list[str],
    handler: UpdateHandler[IpAddressUpdate],
) -> NoReturn:
    proc = subprocess.Popen(
        ip_cmd + ["-o", "monitor", "address"],
        stdout=subprocess.PIPE,
        text=True,
    )
    # initial kickoff (AFTER starting monitoring, to not miss any update)
    logger.info("kickoff IP monitoring with current data")
    kickoff_ip(ip_cmd, handler)
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
        update = IpAddressUpdate.parse_line(line)
        logger.debug(f"pass IP update: {update!r}")
        handler.update(update)


class InterfaceUpdateHandler(UpdateStackHandler[IpAddressUpdate]):
    # TODO regularly check (i.e. 1 hour) if stored lists are still correct
    slaac_prefix: IPv6Interface | None

    def __init__(
        self,
        config: InterfaceConfig,
        nft_handler: UpdateHandler[NftUpdate],
    ) -> None:
        self.nft_handler = nft_handler
        self.lock = RLock()
        self.config = config
        self.addrs = dict[IPInterface, IpAddressUpdate]()
        self.slaac_prefix = None

    def _update_stack(self, data: Sequence[IpAddressUpdate]) -> None:
        nft_updates = tuple(
            chain.from_iterable(self.__parse_update(single) for single in data)
        )
        if len(nft_updates) <= 0:
            return
        self.nft_handler.update_stack(nft_updates)

    def __parse_update(self, data: IpAddressUpdate) -> Iterable[NftUpdate]:
        if data.ifname != self.config.ifname:
            return
        if data.ip.is_link_local:
            logger.debug(
                f"{self.config.ifname}: ignore change for IP {data.ip} because link-local"
            )
            return
        if IpFlag.temporary in data.flags:
            logger.debug(
                f"{self.config.ifname}: ignore change for IP {data.ip} because temporary"
            )
            return  # ignore IPv6 privacy extension addresses
        if IpFlag.tentiative in data.flags:
            logger.debug(
                f"{self.config.ifname}: ignore change for IP {data.ip} because tentiative"
            )
            return  # ignore (yet) tentiative addresses
        logger.debug(f"{self.config.ifname}: process change of IP {data.ip}")
        with self.lock:
            stored = data.ip in self.addrs
            changed = stored != (not data.deleted)
            if data.deleted:
                if not changed:
                    return  # no updates required
                logger.info(f"{self.config.ifname}: deleted IP {data.ip}")
                del self.addrs[data.ip]
            else:
                if not stored:
                    logger.info(f"{self.config.ifname}: discovered IP {data.ip}")
                self.addrs[data.ip] = data  # keep entry up to date
        if changed:
            yield from self.__update_network_sets(data.ip, data.deleted)
        # even if "not changed", still check SLAAC rules because of lifetimes
        slaac_prefix = self.__select_slaac_prefix()
        if self.slaac_prefix == slaac_prefix:
            return  # no SLAAC updates required
        self.slaac_prefix = slaac_prefix
        logger.info(f"{self.config.ifname}: change main SLAAC prefix to {slaac_prefix}")
        yield from (
            self.__empty_slaac_sets()
            if slaac_prefix is None
            else self.__update_slaac_sets(slaac_prefix)
        )

    def __update_network_sets(
        self,
        ip: IPInterface,
        deleted: bool = False,
    ) -> Iterable[NftUpdate]:
        set_prefix = f"{self.config.ifname}v{ip.version}"
        op = NftValueOperation.if_deleted(deleted)
        yield NftUpdate(
            obj_type="set",
            obj_name=f"all_ipv{ip.version}net",
            operation=op,
            values=(f"{self.config.ifname} . {ip.network.compressed}",),
        )
        yield NftUpdate(
            obj_type="set",
            obj_name=f"{set_prefix}net",
            operation=op,
            values=(ip.network.compressed,),
        )
        yield NftUpdate(
            obj_type="set",
            obj_name=f"all_ipv{ip.version}addr",
            operation=op,
            values=(f"{self.config.ifname} . {ip.ip.compressed}",),
        )
        yield NftUpdate(
            obj_type="set",
            obj_name=f"{set_prefix}addr",
            operation=op,
            values=(ip.ip.compressed,),
        )

    def __update_slaac_sets(self, ip: IPv6Interface) -> Iterable[NftUpdate]:
        set_prefix = f"{self.config.ifname}v6"
        op = NftValueOperation.REPLACE
        slaacs = {mac: slaac_eui48(ip.network, mac) for mac in self.config.macs}
        for mac in self.config.macs:
            yield NftUpdate(
                obj_type="set",
                obj_name=f"{set_prefix}_{mac}",
                operation=op,
                values=(slaacs[mac].ip.compressed,),
            )
        slaacs_sub = {
            f"ipv6_{self.config.ifname}_{mac}": addr.ip.compressed
            for mac, addr in slaacs.items()
        }
        for one_set in self.config.sets:
            yield NftUpdate(
                obj_type=one_set.set_type,
                obj_name=one_set.name,
                operation=op,
                values=tuple(one_set.sub_elements(slaacs_sub)),
            )

    def __empty_slaac_sets(self) -> Iterable[NftUpdate]:
        set_prefix = f"{self.config.ifname}v6"
        op = NftValueOperation.EMPTY
        for mac in self.config.macs:
            yield NftUpdate(
                obj_type="set",
                obj_name=f"{set_prefix}_{mac}",
                operation=op,
                values=tuple(),
            )
        for one_set in self.config.sets:
            yield NftUpdate(
                obj_type=one_set.set_type,
                obj_name=one_set.name,
                operation=op,
                values=tuple(),
            )

    def __select_slaac_prefix(self) -> IPv6Interface | None:
        now = datetime.now()
        valid = tuple(data for data in self.addrs.values() if data.ip.version == 6)
        if len(valid) <= 0:
            return None
        selected = max(
            valid,
            key=lambda data: (
                # prefer valid
                1 if now < data.valid_until else 0,
                # prefer global unicast addresses
                1 if data.ip not in IPv6_ULA_NET else 0,
                # if preferred, take longest preferred
                max(now, data.preferred_until),
                # otherwise longest valid
                data.valid_until,
            ),
        )
        return cast(IPv6Interface, selected.ip)

    def gen_set_definitions(self) -> str:
        output = []
        for ip_v in [4, 6]:
            addr_type = f"ipv{ip_v}_addr"
            set_prefix = f"{self.config.ifname}v{ip_v}"
            output.append(gen_set_def("set", f"{set_prefix}addr", addr_type))
            output.append(gen_set_def("set", f"{set_prefix}net", addr_type, "interval"))
            if ip_v != 6:
                continue
            for mac in self.config.macs:
                output.append(gen_set_def("set", f"{set_prefix}_{mac}", addr_type))
        output.extend(s.definition for s in self.config.sets)
        return "\n".join(output)


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
            "    elements = { " + ", ".join(elements) + " }"
            if len(elements) > 0
            else None,
            "}",
        )
        if line is not None
    )
    pass


class NftValueOperation(Enum):
    ADD = auto()
    DELETE = auto()
    REPLACE = auto()
    EMPTY = auto()

    @staticmethod
    def if_deleted(b: bool) -> NftValueOperation:
        return NftValueOperation.DELETE if b else NftValueOperation.ADD

    @staticmethod
    def if_emptied(b: bool) -> NftValueOperation:
        return NftValueOperation.EMPTY if b else NftValueOperation.REPLACE

    @property
    def set_operation(self) -> str:
        assert self.passes_values
        return "destroy" if self == NftValueOperation.DELETE else "add"

    @property
    def passes_values(self) -> bool:
        return self in {
            NftValueOperation.ADD,
            NftValueOperation.REPLACE,
            NftValueOperation.DELETE,
        }

    @property
    def flushes_values(self) -> bool:
        return self in {
            NftValueOperation.REPLACE,
            NftValueOperation.EMPTY,
        }


@define(
    frozen=True,
    kw_only=True,
)
class NftUpdate:
    obj_type: str
    obj_name: str
    operation: NftValueOperation
    values: Sequence[str]

    def to_script(self, table: NftTable) -> str:
        lines = []
        # inet family is the only which supports shared IPv4 & IPv6 entries
        obj_id = f"inet {table} {self.obj_name}"
        if self.operation.flushes_values:
            lines.append(f"flush {self.obj_type} {obj_id}")
        if self.operation.passes_values and len(self.values) > 0:
            op_str = self.operation.set_operation
            values_str = ", ".join(self.values)
            lines.append(f"{op_str} element {obj_id} {{ {values_str} }}")
        return "\n".join(lines)


class NftUpdateHandler(UpdateStackHandler[NftUpdate]):
    def __init__(
        self,
        update_cmd: Sequence[str],
        table: NftTable,
        handler: UpdateHandler[None],
    ) -> None:
        self.update_cmd = update_cmd
        self.table = table
        self.handler = handler

    def _update_stack(self, data: Sequence[NftUpdate]) -> None:
        logger.debug("compile stacked updates for nftables")
        script = "\n".join(
            map(
                lambda u: u.to_script(table=self.table),
                data,
            )
        )
        logger.debug(f"pass updates to nftables:\n{script}")
        subprocess.run(
            list(self.update_cmd) + ["-f", "-"],
            input=script,
            check=True,
            text=True,
        )
        self.handler.update(None)


class SystemdHandler(UpdateHandler[object]):
    def update(self, data: object) -> None:
        # TODO improve status updates
        daemon.notify("READY=1\nSTATUS=operating …\n")

    def update_stack(self, data: Sequence[object]) -> None:
        self.update(None)


@define(
    frozen=True,
    kw_only=True,
)
class SetConfig:
    ifname: str
    set_type: str
    name: str
    data_type: str
    flags: str | None
    elements: Sequence[Template] = field()

    @elements.validator
    def __elem_validate(self, attribute: str, value: Sequence[Template]) -> None:
        regex = self.__supported_vars
        for temp in self.elements:
            for var in temp.get_identifiers():
                m = regex.search(var)
                if m is None:
                    raise ValueError(
                        f"set {self.name!r} for if {self.ifname!r} uses invalid template variable {var!r}"
                    )

    @property
    def __supported_vars(self) -> re.Pattern[str]:
        return re.compile(rf"^ipv6_{re.escape(self.ifname)}_(?P<mac>[0-9a-f]{{12}})$")

    @property
    def embedded_macs(self) -> Iterable[MACAddress]:
        regex = self.__supported_vars
        for temp in self.elements:
            for var in temp.get_identifiers():
                m = regex.search(var)
                assert m != None
                yield to_mac(m.group("mac"))  # type: ignore[union-attr]

    @property
    def definition(self) -> str:
        return gen_set_def(
            set_type=self.set_type,
            name=self.name,
            data_type=self.data_type,
            flags=self.flags,
            # non matching rules at the beginning (in static part)
            # to verify that all supplied patterns are correct
            # undefined address should be safest to use here, because:
            # - as src, it is valid, but if one can spoof this one, it can spoof other addresses (and routers should have simple anti-spoof mechanisms in place)
            # - as dest, it is invalid
            # - as NAT target, it is invalid
            elements=self.sub_elements(defaultdict(lambda: "::")),
        )

    def sub_elements(self, substitutions: Mapping[str, str]) -> Sequence[str]:
        return tuple(elem.substitute(substitutions) for elem in self.elements)

    @classmethod
    def from_json(cls, *, ifname: str, name: str, obj: JsonObj) -> SetConfig:
        assert set(obj.keys()) <= set(("set_type", "name", "type", "flags", "elements"))
        set_type = obj["set_type"]
        assert isinstance(set_type, str)
        data_type = obj["type"]
        assert isinstance(data_type, str)
        flags = obj.get("flags")
        assert flags is None or isinstance(flags, str)
        elements = obj["elements"]
        assert isinstance(elements, Sequence) and all(
            isinstance(elem, str) for elem in elements
        )
        templates = tuple(map(lambda s: Template(cast(str, s)), elements))
        return SetConfig(
            set_type=set_type,
            ifname=ifname,
            name=name,
            data_type=data_type,
            flags=flags,
            elements=templates,
        )


@define(
    frozen=True,
    kw_only=True,
)
class InterfaceConfig:
    ifname: IfName
    macs_direct: Sequence[MACAddress]
    sets: Sequence[SetConfig]

    @cached_property
    def macs(self) -> Sequence[MACAddress]:
        return tuple(
            set(
                chain(
                    self.macs_direct,
                    (mac for one_set in self.sets for mac in one_set.embedded_macs),
                )
            )
        )

    @staticmethod
    def from_json(ifname: str, obj: JsonObj) -> InterfaceConfig:
        assert set(obj.keys()) <= set(("macs", "sets"))
        macs = obj.get("macs")
        assert macs is None or isinstance(macs, Sequence)
        sets = obj.get("sets")
        assert sets is None or isinstance(sets, Mapping)
        return InterfaceConfig(
            ifname=IfName(ifname),
            macs_direct=tuple()
            if macs is None
            else tuple(to_mac(cast(str, mac)) for mac in macs),
            sets=tuple()
            if sets is None
            else tuple(
                SetConfig.from_json(
                    ifname=ifname, name=name, obj=cast(JsonObj, one_set)
                )
                for name, one_set in sets.items()
            ),
        )


@define(
    frozen=True,
    kw_only=True,
)
class AppConfig:
    nft_table: NftTable
    interfaces: Sequence[InterfaceConfig]

    @staticmethod
    def from_json(obj: JsonObj) -> AppConfig:
        assert set(obj.keys()) <= set(("interfaces", "nftTable"))
        nft_table = obj["nftTable"]
        assert isinstance(nft_table, str)
        interfaces = obj["interfaces"]
        assert isinstance(interfaces, Mapping)
        return AppConfig(
            nft_table=NftTable(nft_table),
            interfaces=tuple(
                InterfaceConfig.from_json(ifname, cast(JsonObj, if_cfg))
                for ifname, if_cfg in interfaces.items()
            ),
        )


def read_config_file(path: Path) -> AppConfig:
    with path.open("r") as fh:
        json_data = json.load(fh)
    logger.debug(repr(json_data))
    return AppConfig.from_json(json_data)


LOG_LEVEL_MAP = {
    "critical": logging.CRITICAL,
    "error": logging.ERROR,
    "warning": logging.WARNING,
    "info": logging.INFO,
    "debug": logging.DEBUG,
}


def _gen_if_updater(
    configs: Sequence[InterfaceConfig], nft_updater: UpdateHandler[NftUpdate]
) -> Sequence[InterfaceUpdateHandler]:
    return tuple(
        InterfaceUpdateHandler(
            config=if_cfg,
            nft_handler=nft_updater,
        )
        for if_cfg in configs
    )


def static_part_generation(config: AppConfig) -> None:
    for ipV in [4, 6]:
        print(gen_set_def("set", f"all_ipv{ipV}addr", f"ifname . ipv{ipV}_addr"))
        print(
            gen_set_def(
                "set", f"all_ipv{ipV}net", f"ifname . ipv{ipV}_addr", "interval"
            )
        )
    dummy = IgnoreHandler()
    if_updater = _gen_if_updater(config.interfaces, dummy)
    for if_up in if_updater:
        print(if_up.gen_set_definitions())


def service_execution(args: argparse.Namespace, config: AppConfig) -> NoReturn:
    nft_updater = NftUpdateHandler(
        table=config.nft_table,
        update_cmd=shlex.split(args.nft_command),
        handler=SystemdHandler(),
    )
    if_updater = _gen_if_updater(config.interfaces, nft_updater)
    burst_handler = UpdateBurstHandler[IpAddressUpdate](
        burst_interval=0.5,
        handler=if_updater,
    )
    monitor_ip(shlex.split(args.ip_command), burst_handler)


def setup_logging(args: Any) -> None:
    systemd_service = os.environ.get("INVOCATION_ID") and Path("/dev/log").exists()
    if systemd_service:
        logger.setLevel(logging.DEBUG)
        logger.addHandler(JournalHandler(SYSLOG_IDENTIFIER="nft-update-addresses"))
    else:
        logging.basicConfig()  # get output to stdout/stderr
        logger.setLevel(LOG_LEVEL_MAP[args.log_level])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("-c", "--config-file", required=True)
    parser.add_argument("--check-config", action="store_true")
    parser.add_argument("--output-set-definitions", action="store_true")
    parser.add_argument("--ip-command", default="/usr/bin/env ip")
    parser.add_argument("--nft-command", default="/usr/bin/env nft")
    parser.add_argument(
        "-l",
        "--log-level",
        default="error",
        choices=LOG_LEVEL_MAP.keys(),
        help="Log level for outputs to stdout/stderr (ignored when launched in a systemd service)",
    )
    args = parser.parse_args()
    setup_logging(args)
    config = read_config_file(Path(args.config_file))
    if args.check_config:
        return
    if args.output_set_definitions:
        return static_part_generation(config)
    service_execution(args, config)


if __name__ == "__main__":
    main()
