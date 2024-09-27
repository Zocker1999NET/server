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
    raise args[0]


# ensure exceptions in any thread brings the program down
# important for proper error detection via tests & in random cases in real world

threading.excepthook = raise_and_exit


JsonVal: TypeAlias = Union["JsonObj", "JsonList", str, int, bool]
JsonList: TypeAlias = Sequence[JsonVal]
JsonObj: TypeAlias = Mapping[str, JsonVal]

T = TypeVar("T", contravariant=True)

MACAddress = NewType("MACAddress", str)
# format: aabbccddeeff (lower-case, without separators)
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
            f"a SLAAC IPv6 address requires a CIDR of at least /64, got {prefix}"
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
        .*  # lifetimes which are not interesting yet
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
    ip: IPv4Interface | IPv6Interface
    scope: str
    flags: IpFlag

    @staticmethod
    def parse_line(line: str) -> IpAddressUpdate:
        m = IP_MON_PATTERN.search(line)
        if not m:
            raise Exception(f"Could not parse ip monitor output: {line!r}")
        grp = m.groupdict()
        ip_type: type[IPv4Interface | IPv6Interface] = (
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
        )


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

    def __init__(
        self,
        config: InterfaceConfig,
        nft_handler: UpdateHandler[NftUpdate],
    ) -> None:
        self.nft_handler = nft_handler
        self.lock = RLock()
        self.config = config
        self.ipv4Addrs = list[IPv4Interface]()
        self.ipv6Addrs = list[IPv6Interface]()

    def _update_stack(self, data: Sequence[IpAddressUpdate]) -> None:
        nft_updates = tuple(
            chain.from_iterable(self.__gen_updates(single) for single in data)
        )
        if len(nft_updates) <= 0:
            return
        self.nft_handler.update_stack(nft_updates)

    def __gen_updates(self, data: IpAddressUpdate) -> Iterable[NftUpdate]:
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
            ip_list: list[IPv4Interface] | list[IPv6Interface] = (
                self.ipv6Addrs if isinstance(data.ip, IPv6Interface) else self.ipv4Addrs
            )
            if data.deleted != (data.ip in ip_list):
                return  # no change required
            if data.deleted:
                logger.info(f"{self.config.ifname}: deleted IP {data.ip}")
                ip_list.remove(data.ip)  # type: ignore[arg-type]
            else:
                logger.info(f"{self.config.ifname}: discovered IP {data.ip}")
                ip_list.append(data.ip)  # type: ignore[arg-type]
        set_prefix = f"{self.config.ifname}v{data.ip.version}"
        op = NftValueOperation.if_deleted(data.deleted)
        yield NftUpdate(
            obj_type="set",
            obj_name=f"all_ipv{data.ip.version}net",
            operation=op,
            values=(f"{self.config.ifname} . {data.ip.network.compressed}",),
        )
        yield NftUpdate(
            obj_type="set",
            obj_name=f"{set_prefix}net",
            operation=op,
            values=(data.ip.network.compressed,),
        )
        yield NftUpdate(
            obj_type="set",
            obj_name=f"all_ipv{data.ip.version}addr",
            operation=op,
            values=(f"{self.config.ifname} . {data.ip.ip.compressed}",),
        )
        yield NftUpdate(
            obj_type="set",
            obj_name=f"{set_prefix}addr",
            operation=op,
            values=(data.ip.ip.compressed,),
        )
        # ignore unique link locals for prefix-dependent destinations
        if data.ip in IPv6_ULA_NET:
            return
        if data.ip.version != 6:
            return
        op = NftValueOperation.if_emptied(data.deleted)
        slaacs = {mac: slaac_eui48(data.ip.network, mac) for mac in self.config.macs}
        for mac in self.config.macs:
            yield NftUpdate(
                obj_type="set",
                obj_name=f"{set_prefix}_{mac}",
                operation=op,
                values=(slaacs[mac].ip.compressed,),
            )
        for proto in self.config.protocols:
            yield NftUpdate(
                obj_type="set",
                obj_name=f"{set_prefix}exp{proto.protocol}",
                operation=op,
                values=tuple(
                    f"{slaacs[mac].ip.compressed} . {port}"
                    for mac, portList in proto.exposed.items()
                    for port in portList
                ),
            )
            yield NftUpdate(
                obj_type="map",
                obj_name=f"{set_prefix}dnat{proto.protocol}",
                operation=op,
                values=tuple(
                    f"{wan} : {slaacs[mac].ip.compressed} . {lan}"
                    for mac, portMap in proto.forwarded.items()
                    for wan, lan in portMap.items()
                ),
            )

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
            for proto in self.config.protocols:
                output.append(
                    gen_set_def(
                        "set",
                        f"{set_prefix}exp{proto.protocol}",
                        f"{addr_type} . inet_service",
                    )
                )
                output.append(
                    gen_set_def(
                        "map",
                        f"{set_prefix}dnat{proto.protocol}",
                        f"inet_service : {addr_type} . inet_service",
                    )
                )
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
        # daemon.notify("READY=1\nSTATUS=Updated successfully.\n")
        daemon.notify("READY=1\n")

    def update_stack(self, data: Sequence[object]) -> None:
        self.update(None)


@define(
    frozen=True,
    kw_only=True,
)
class ProtocolConfig:
    protocol: NftProtocol
    exposed: Mapping[MACAddress, Sequence[Port]]
    "only when direct public IPs are available"
    forwarded: Mapping[MACAddress, Mapping[Port, Port]]  # wan -> lan
    "i.e. DNAT"

    @staticmethod
    def from_json(protocol: str, obj: JsonObj) -> ProtocolConfig:
        assert set(obj.keys()) <= set(("exposed", "forwarded"))
        exposed_raw = obj.get("exposed")
        exposed = defaultdict[MACAddress, list[Port]](list)
        if exposed_raw is not None:
            assert isinstance(exposed_raw, Sequence)
            for fwd in exposed_raw:
                assert isinstance(fwd, Mapping)
                dest = to_mac(fwd["dest"])  # type: ignore[arg-type]
                port = to_port(fwd["port"])  # type: ignore[arg-type]
                exposed[dest].append(port)
        forwarded_raw = obj.get("forwarded")
        forwarded = defaultdict[MACAddress, dict[Port, Port]](dict)
        if forwarded_raw is not None:
            assert isinstance(forwarded_raw, Sequence)
            for smap in forwarded_raw:
                assert isinstance(smap, Mapping)
                dest = to_mac(smap["dest"])  # type: ignore[arg-type]
                wanPort = to_port(smap["wanPort"])  # type: ignore[arg-type]
                lanPort = to_port(smap["lanPort"])  # type: ignore[arg-type]
                forwarded[dest][wanPort] = lanPort
        return ProtocolConfig(
            protocol=NftProtocol(protocol),
            exposed=exposed,
            forwarded=forwarded,
        )


@define(
    frozen=True,
    kw_only=True,
)
class InterfaceConfig:
    ifname: IfName
    macs_direct: Sequence[MACAddress]
    protocols: Sequence[ProtocolConfig]

    @cached_property
    def macs(self) -> Sequence[MACAddress]:
        return tuple(
            set(
                chain(
                    self.macs_direct,
                    (mac for proto in self.protocols for mac in proto.exposed.keys()),
                    (mac for proto in self.protocols for mac in proto.forwarded.keys()),
                )
            )
        )

    @staticmethod
    def from_json(ifname: str, obj: JsonObj) -> InterfaceConfig:
        assert set(obj.keys()) <= set(("macs", "ports"))
        macs = obj.get("macs")
        assert macs == None or isinstance(macs, Sequence)
        ports = obj.get("ports")
        assert ports == None or isinstance(ports, Mapping)
        return InterfaceConfig(
            ifname=IfName(ifname),
            macs_direct=tuple()
            if macs == None
            else tuple(to_mac(cast(str, mac)) for mac in macs),  # type: ignore[union-attr]
            protocols=tuple()
            if ports == None
            else tuple(
                ProtocolConfig.from_json(proto, cast(JsonObj, proto_cfg))
                for proto, proto_cfg in ports.items()  # type: ignore[union-attr]
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
