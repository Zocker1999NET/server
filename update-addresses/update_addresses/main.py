#!/usr/bin/env python3

from __future__ import annotations

from argparse import (
    ArgumentParser,
    Namespace,
)
from collections.abc import (
    Sequence,
)
from datetime import (
    datetime,
)
from enum import (
    Enum,
    auto,
)
from ipaddress import (
    IPv6Interface,
)
from itertools import chain
import os
from pathlib import Path
import shlex
from signal import SIGHUP, signal
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
    NoReturn,
    TypeVar,
    cast,
)

from attrs import (
    define,
)
from systemd import daemon  # type: ignore[import-untyped]

from .argparse_ext import ArgumentParserExtender
from .config import (
    AppConfig,
    InterfaceConfig,
    read_config_file,
)
from .handlers import (
    IgnoreHandler,
    UpdateHandler,
    UpdateBurstHandler,
    UpdateStackHandler,
)
from .logging import LogMgr
from .ip_mon import (
    IpAddressUpdate,
    IpFlag,
    IPNetwork,
    IPInterface,
    IpMonitor,
    IpUpdate,
    SpecialIpUpdate,
)
from .net_utils import (
    IPv6_ULA_NET,
    NftTable,
    gen_set_def,
    slaac_eui48,
)


log_mgr = LogMgr(__name__)
logger = log_mgr.logger


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

T = TypeVar("T", contravariant=True)


class InterfaceUpdateHandler(UpdateStackHandler[IpUpdate]):
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

    def _update_stack(self, data: Sequence[IpUpdate]) -> None:
        nft_updates = tuple(
            chain.from_iterable(self.__parse_update(single) for single in data)
        )
        if len(nft_updates) <= 0:
            return
        self.nft_handler.update_stack(nft_updates)

    def __parse_update(self, data: IpUpdate) -> Iterable[NftUpdate]:
        if isinstance(data, SpecialIpUpdate):
            if data is not SpecialIpUpdate.FLUSH_RULES:
                raise ValueError(f"unknown special update {data!r}")
            # TODO maybe flush all sets completely, for good measure
            for addr in self.addrs.keys():
                yield from self.__update_network_sets(addr.network, deleted=True)
                yield from self.__update_address_sets(addr, deleted=True)
            self.addrs = dict()
            yield from self.__empty_slaac_sets()
            self.slaac_prefix = None
            return
        if data.ifname != self.config.ifname:
            return
        if data.ip.is_link_local:
            logger.debug(
                f"{self.config.ifname}: ignore change for IP {data.ip} because link-local"
            )
            return
        # do NOT ignore temporary (e.g. IPv6 privacy extension) addresses
        # because otherwise the address is not listed as assigned to the interface possibly breaking scenarios
        # e.g. where incoming packets are verified for matching interface & dest IP combination ("inputDestination" in my NixOS router module)
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
            yield from self.__update_network_sets(data.ip.network, data.deleted)
            yield from self.__update_address_sets(data.ip, data.deleted)
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
        net: IPNetwork,
        deleted: bool = False,
    ) -> Iterable[NftUpdate]:
        set_prefix = f"{self.config.ifname}v{net.version}"
        op = NftValueOperation.if_deleted(deleted)
        yield NftUpdate(
            obj_type="set",
            obj_name=f"all_ipv{net.version}net",
            operation=op,
            values=(f"{self.config.ifname} . {net.compressed}",),
        )
        yield NftUpdate(
            obj_type="set",
            obj_name=f"{set_prefix}net",
            operation=op,
            values=(net.compressed,),
        )

    def __update_address_sets(
        self,
        ip: IPInterface,
        deleted: bool = False,
    ) -> Iterable[NftUpdate]:
        set_prefix = f"{self.config.ifname}v{ip.version}"
        op = NftValueOperation.if_deleted(deleted)
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
                # defer temporary (precautionary)
                0 if IpFlag.temporary in data.flags else 1,
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


class SystemdReadyHandler(UpdateHandler[object]):
    def update(self, data: object) -> None:
        # TODO improve status updates
        daemon.notify("READY=1\nSTATUS=operating …\n")

    def update_stack(self, data: Sequence[object]) -> None:
        self.update(None)


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


def on_service_reload(ip_mon: IpMonitor) -> None:
    # for now, reloading is kind of a hack to be able to react to nftables.service reloadings
    # because then we need to re-apply all of our rules again
    logger.info(
        "reload signal received; reapply all rules (config file will not be read on reload)"
    )
    daemon.notify("RELOADING=1\nSTATUS=reloading all rules …\n")
    ip_mon.kickoff()


def service_execution(args: Namespace, config: AppConfig) -> NoReturn:
    nft_updater = NftUpdateHandler(
        table=config.nft_table,
        update_cmd=shlex.split(args.nft_command),
        handler=SystemdReadyHandler(),
    )
    nft_burst_handler = UpdateBurstHandler[NftUpdate](
        burst_interval=0.1,
        handler=(nft_updater,),
    )
    if_updater = _gen_if_updater(config.interfaces, nft_burst_handler)
    burst_handler = UpdateBurstHandler[IpUpdate](
        burst_interval=0.1,
        handler=if_updater,
    )
    ip_mon = IpMonitor(
        handler=burst_handler,
        ip_cmd=shlex.split(args.ip_command),
    )
    # in case of systemd service reload
    signal(SIGHUP, lambda *_a, **_b: on_service_reload(ip_mon))
    ip_mon.monitor()


def main() -> None:
    parser = ArgumentParserExtender.init(
        ArgumentParser(),
        log_mgr,
    )
    parser.add_argument("-c", "--config-file", required=True)
    parser.add_argument("--check-config", action="store_true")
    parser.add_argument("--output-set-definitions", action="store_true")
    parser.add_argument("--ip-command", default="/usr/bin/env ip")
    parser.add_argument("--nft-command", default="/usr/bin/env nft")
    args = parser.parse_args()
    config = read_config_file(Path(args.config_file))
    if args.check_config:
        return
    if args.output_set_definitions:
        return static_part_generation(config)
    service_execution(args, config)


if __name__ == "__main__":
    main()
