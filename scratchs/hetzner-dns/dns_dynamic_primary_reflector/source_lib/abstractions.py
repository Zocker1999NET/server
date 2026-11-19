from __future__ import annotations

from collections.abc import (
    Sequence,
)
from dataclasses import (
    dataclass,
)
from enum import (
    Enum,
    auto,
)
import logging
from typing import (
    Generic,
    Protocol,
    TypeVar,
)

from ..action_lib import (
    SourceError,
)


V = TypeVar("V", covariant=True)


logger = logging.getLogger(__name__)


class NonInfo(Enum):
    "used internally instead of None, so that None can be safely used as type of a value"

    NO_RESULT = auto()
    "no value was obtained"


@dataclass(
    frozen=True,
    order=False,
    slots=True,
)
class SourceReturn(Generic[V]):
    "outcome of one retrieval attempt: a value, an error or nothing"

    source_name: str
    "origin of this result"
    info: V | NonInfo
    "obtained value, NO_RESULT if none"
    error: str | None
    "describes the failure, None on success"
    warnings: Sequence[str] = ()
    "non-fatal notices collected during retrieval"

    def __post_init__(self) -> None:
        "ensures every result carries either an info or an error"
        assert self.info is not NonInfo.NO_RESULT or self.error is not None

    def unpack_safe(self) -> V | NonInfo:
        "logs warnings and errors, returning the info without raising"
        self.__log_warnings()
        if self.error is not None:
            logger.error("%s: %s", self.source_name, self.error)
        return self.info

    def unpack(self) -> V:
        "logs warnings and returns the info, raising SourceError on failure"
        self.__log_warnings()
        if self.error is not None:
            raise SourceError(self.source_name, self.error, warn_tb=False)
        assert self.info != NonInfo.NO_RESULT, (
            "should already be checked by __post_init__ assertations"
        )
        return self.info

    def __log_warnings(self) -> None:
        "logs each collected warning once"
        for warning in self.warnings:
            logger.warning("%s: %s", self.source_name, warning)


class InfoSource(Protocol[V]):
    def retrieve_info(self) -> SourceReturn[V]:
        """retrieves info from source.

        In case of expectable exceptions (i.e. not the program is buggy but e.g. the network),
        return a SourceReturn with info=None and error set to a message.
        Exceptions raised by this function are, by definition, bugs.
        """
        ...

    @property
    def source_name(self) -> str:
        "human-readable name of this source"
        ...
