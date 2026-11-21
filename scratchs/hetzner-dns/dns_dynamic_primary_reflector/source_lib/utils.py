from __future__ import annotations

import traceback
from abc import ABC, abstractmethod
from dataclasses import (
    dataclass,
    field,
)

from ..action_lib import (
    SimpleSource,
    SourceError,
)
from .abstractions import (
    InfoSource,
    NonInfo,
    SourceReturn,
    V_co,
)


@dataclass(
    eq=False,
    init=False,
    frozen=True,
    order=False,
    slots=True,
)
class InfoSourceImpl(ABC, InfoSource[V_co]):
    "base class packing _retrieve results and SourceErrors into SourceReturns"

    __warnings: list[str] = field(init=False, default_factory=list)
    "warnings collected over the lifetime of this source"

    def retrieve_info(self) -> SourceReturn[V_co]:
        try:
            return SourceReturn(
                source_name=self.source_name,
                info=self._retrieve(),
                error=None,
                warnings=self.__warnings,
            )
        except SourceError as err:
            if err.warn_tb:
                self.__warnings.append("".join(traceback.format_exception(err)))
            return SourceReturn(
                source_name=self.source_name,
                info=NonInfo.NO_RESULT,
                error=err.error_msg,
                warnings=self.__warnings,
            )

    @abstractmethod
    def _retrieve(self) -> V_co:
        """implements method on how to retrieve info

        If an error occurs,
        the type of the raised exception should be used to differentiate the assumed source of the error:
        A raised SourceError means a rather expectable error which might resolve itself (i.e. remote down).
        A SourceError will be packed into a SourceReturn.

        Any other Exception does indicate a bug in the program,
        especially if an expectable error is not raised as a SourceError.
        """
        ...

    def _warn(self, warning: str) -> None:
        "records a warning to be attached to upcoming results"
        self.__warnings.append(warning)

    @property
    @abstractmethod
    def source_name(self) -> str: ...


@dataclass(
    frozen=True,
    order=False,
    slots=True,
)
class StaticSource(InfoSource[V_co]):
    "always returns one fixed SourceReturn, e.g. for testing"

    return_val: SourceReturn[V_co]
    "the constant result to return"

    def retrieve_info(self) -> SourceReturn[V_co]:
        return self.return_val


@dataclass(
    frozen=True,
    order=False,
    slots=True,
)
class SourceUnpacker(SimpleSource[V_co]):
    "adapts a SourceReturn-based InfoSource to the raise-based SimpleSource"

    source: InfoSource[V_co]
    "the wrapped source"

    @property
    def current_value(self) -> V_co:
        return self.source.retrieve_info().unpack()


@dataclass(
    frozen=True,
    order=False,
    slots=True,
)
class NotNoneSource(SimpleSource[V_co]):
    "converts a nullable source into one that raises on None"

    source: SimpleSource[V_co | None]
    "the wrapped source"

    @property
    def current_value(self) -> V_co:
        val = self.source.current_value
        if val is None:
            raise ValueError("source is required to return something but returned None")
        return val
