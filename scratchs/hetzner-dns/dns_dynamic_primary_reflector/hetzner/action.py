from __future__ import annotations

from ipaddress import ip_address

from hcloud import Client
from hcloud.zones import (
    ZonePrimaryNameserver,
    ZonesClient,
)

from ..action_lib import Action


class HetznerPrimaryAction(Action[list[str]]):
    "applies an IP list as the primary nameservers of one Hetzner zone"

    __api: ZonesClient
    "Hetzner DNS zones client used for updates"
    __zone_name: str
    "name of the zone to update"

    @staticmethod
    def from_api_key(api_key: str, zone_name: str) -> HetznerPrimaryAction:
        "creates an action authenticating with the given API key"
        return HetznerPrimaryAction(
            api=Client(token=api_key).zones,
            zone_name=zone_name,
        )

    def __init__(self, api: ZonesClient, zone_name: str) -> None:
        "wires the zones client and the target zone name"
        super().__init__()
        self.__api = api
        self.__zone_name = zone_name

    def update(self, data: list[str]) -> None:
        # zone id is refetched on every update on purpose
        # in case the zone is re-created or the API is not accessible when this app boots
        for ip in data:
            # confirm that given IPs can be parsed
            ip_address(ip)
        zone = self.__api.get(self.__zone_name)
        zone.change_primary_nameservers(list(map(ZonePrimaryNameserver, data)))
