import bisect
from collections.abc import (
    Mapping,
)
import logging
from functools import (
    cache,
)

import requests


PYTHON_DEFAULT_PRIORITY = logging.INFO

# source: https://docs.ntfy.sh/publish/#message-priority
NTFY_LOWEST_PRIORITY = 1
NTFY_DEFAULT_PRIORITY = 3


class NtfyHandler(logging.Handler):
    "publishes log records as messages to an ntfy topic"

    __url: str
    "ntfy topic endpoint to publish to"
    __priority_map: dict[int, int]
    "python level to ntfy priority mapping"
    __session: requests.Session
    "shared HTTP session for publishing"

    def __init__(
        self,
        url: str,
        priority_map: Mapping[int, int] | None = None,
    ) -> None:
        "prepares the HTTP session and the priority mapping"
        super().__init__()
        self.__url = url
        self.__session = requests.Session()
        if priority_map is None:
            self.__priority_map = {PYTHON_DEFAULT_PRIORITY: NTFY_DEFAULT_PRIORITY}
        else:
            self.__priority_map = dict(priority_map)

    def emit(self, record: logging.LogRecord) -> None:
        entry = self.format(record)
        self.__session.post(
            url=self.__url,
            data=entry,
            headers={
                "X-Priority": str(self.__map_priority(record.levelno)),
            },
        )

    @cache
    def __map_priority(self, prio: int) -> int:
        keys = sorted(self.__priority_map.keys())
        pos = bisect.bisect_right(keys, prio)
        if pos == 0:
            return NTFY_LOWEST_PRIORITY
        return self.__priority_map[keys[pos - 1]]
