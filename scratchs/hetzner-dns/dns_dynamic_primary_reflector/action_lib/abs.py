from __future__ import annotations

from dataclasses import (
    dataclass,
)
from typing import (
    Protocol,
    TypeVar,
)


V = TypeVar("V")
V_co = TypeVar("V_co", covariant=True)
V_contra = TypeVar("V_contra", contravariant=True)


class SimpleSource(Protocol[V_co]):
    "read-only output end of a processing pipeline"

    @property
    def current_value(self) -> V_co:
        "current value of this pipeline stage; raises on expectable failure"
        ...


@dataclass(
    eq=False,
    frozen=True,
    order=False,
    slots=True,
)
class SourceError(Exception):
    "the one expectable error allowed to cross the SimpleSource boundary"

    source_name: str
    "origin of the failed retrieval"
    error_msg: str
    "description of the failure"
    warn_tb: bool = True
    "capture a full traceback as a warning"

    def __post_init__(self) -> None:
        Exception.__init__(self, self.error_msg)


class Action(Protocol[V_contra]):
    "sink end of a processing pipeline, applying new values"

    def update(self, data: V_contra) -> None:
        "applies the new value to its target"
        ...


class UpdateSupervisor(Protocol[V]):
    "performs updates through an Action while recording their outcome"

    def attempt_update(self, data: V) -> bool:
        "applies the new data via its action; True on success"
        ...

    @property
    def last_error(self) -> Exception | None:
        "error of the most recent failed update, if any"
        ...

    @property
    def current_value(self) -> V | None:
        "last successfully applied value, if any"
        ...
