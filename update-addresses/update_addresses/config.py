from __future__ import annotations

from collections import defaultdict
from collections.abc import (
    Mapping,
    Sequence,
)
from functools import cached_property
from itertools import chain
import json
from pathlib import Path
import re
from string import Template
from typing import (
    Iterable,
    TypeAlias,
    Union,
    cast,
)

from attrs import (
    define,
    field,
)

from .ip_mon import (
    IfName,
)
from .logging import LogMgr
from .net_utils import (
    MACAddress,
    NftTable,
    gen_set_def,
    to_mac,
)


log_mgr = LogMgr(__name__)
logger = log_mgr.logger


JsonVal: TypeAlias = Union["JsonObj", "JsonList", str, int, bool]
JsonList: TypeAlias = Sequence[JsonVal]
JsonObj: TypeAlias = Mapping[str, JsonVal]


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
                yield to_mac(m.group("mac"))

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
            macs_direct=(
                tuple()
                if macs is None
                else tuple(to_mac(cast(str, mac)) for mac in macs)
            ),
            sets=(
                tuple()
                if sets is None
                else tuple(
                    SetConfig.from_json(
                        ifname=ifname, name=name, obj=cast(JsonObj, one_set)
                    )
                    for name, one_set in sets.items()
                )
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
