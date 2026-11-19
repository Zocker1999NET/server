from __future__ import annotations

import logging
from dataclasses import (
    dataclass,
)
from datetime import (
    datetime,
)
from typing import (
    NoReturn,
    Protocol,
    TypeVar,
)

from ..action_lib import (
    SimpleSource,
)
from ..type_lib import (
    InfoVal,
)

K = TypeVar("K", bound=str)
K_contra = TypeVar("K_contra", bound=str, contravariant=True)
V = TypeVar("V", bound=InfoVal)


logger = logging.getLogger(__name__)


class CachedStateError(Exception):
    "re-raises an error that was previously recorded in a persisted state"


@dataclass(
    frozen=True,
    kw_only=True,
    order=False,
)
class State(SimpleSource[V]):
    "persistent record of the last value and the last error, each with its date"

    value: V | None = None
    "last recorded value, if any"
    value_date: datetime | None = None
    "time the value was recorded"
    error: Exception | str | None = None
    "last recorded error; a traceback str after serialization"
    error_date: datetime | None = None
    "time the error was recorded"

    @property
    def current_value(self) -> V:
        "the recorded value; raises if none was ever recorded successfully"
        if not self.has_any_value:
            if not self.has_any_error:
                raise RuntimeError(
                    "State unexpectedly has value=None without any error"
                )
            self.__raise_error()
        assert self.value is not None
        if not self.was_last_successful:
            logger.warning(
                "load cached state from %s, logged exception at %s: %s",
                self.value_date,
                self.error_date,
                self.error,
            )
        return self.value

    def __raise_error(self) -> NoReturn:
        "re-raises the stored error, converting str errors to exceptions"
        logger.error(
            "will raise exception from state, exception originally occured at %s",
            self.error_date,
        )
        if isinstance(self.error, Exception):
            raise self.error
        raise CachedStateError(str(self.error))

    @property
    def was_last_successful(self) -> bool:
        "True if the most recent recorded event was a successful value"
        if self.value_date is None:
            return False
        if self.error_date is None:
            return True
        return self.error_date <= self.value_date

    @property
    def has_any_value(self) -> bool:
        "True if a value was ever recorded"
        return self.value is not None and self.value_date is not None

    @property
    def has_any_error(self) -> bool:
        "True if an error was ever recorded"
        return self.error_date is not None

    @property
    def was_attempted_once(self) -> bool:
        "True if any value or error was ever recorded"
        return self.value_date is not None or self.error_date is not None

    def merge(self, other: State[V] | None) -> State[V]:
        "combines two states, keeping value and error independently by date"
        if other is None:
            return self
        newer_val = (
            self if State.__alpha_newer(self.value_date, other.value_date) else other
        )
        newer_err = (
            self if State.__alpha_newer(self.error_date, other.error_date) else other
        )
        return State[V](
            value=newer_val.value,
            value_date=newer_val.value_date,
            error=newer_err.error,
            error_date=newer_err.error_date,
        )

    @staticmethod
    def __alpha_newer(alpha_date: datetime | None, beta_date: datetime | None) -> bool:
        "True if alpha_date is known to be newer than beta_date"
        return beta_date is None or (alpha_date is not None and beta_date <= alpha_date)


class StateManager(Protocol[K_contra, V]):
    "stores states identified by string keys, with load & store support"

    def for_key(self, key: K_contra) -> SingleManager[V]:
        "returns a SingleManager view onto the given key"
        ...

    def submit_state(self, key: K_contra, state: State[V]) -> None:
        "merges the state into the stored one for the given key"
        ...

    def get_state(self, key: K_contra) -> State[V]:
        "returns the stored state for the given key, empty if unknown"
        ...

    def load_states(self) -> None:
        "restores all stored states from the backing persistence"
        ...

    def store_states(self) -> None:
        "persists all currently known states"
        ...


class SingleManager(SimpleSource[V], Protocol[V]):
    "state view and writer for a single key of a StateManager"

    def submit_success(self, value: V) -> None:
        "records a successfully obtained value"
        ...

    def submit_error(self, exc: Exception) -> None:
        "records a failed attempt"
        ...

    def submit(self, state: State[V]) -> None:
        "merges the given state into the stored one"
        ...

    @property
    def current_value(self) -> V:
        "the recorded value; raises if none exists"
        ...

    @property
    def current_state(self) -> State[V]:
        "the full state held for this key"
        ...
