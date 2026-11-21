from __future__ import annotations

import traceback
from abc import (
    ABC,
)
from collections.abc import Iterable
from datetime import (
    UTC,
    datetime,
)
from typing import (
    Generic,
    cast,
)

from ..type_lib import (
    JsonVal,
)
from .abstractions import (
    K,
    SingleManager,
    State,
    StateManager,
    V,
)


class StateManagerSingleImpl(StateManager[K, V], ABC, Generic[K, V]):
    "provides SingleManager views on top of a StateManager"

    def for_key(self, key: K) -> SingleManager[V]:
        return SingleManagerImpl(self, key)


class StateManagerBackendImpl(StateManager[K, V], ABC, Generic[K, V]):
    "holds states in memory and persists them on every change"

    __states: dict[K, State[V]]

    def __init__(self) -> None:
        self._reset()

    def submit_state(self, key: K, state: State[V]) -> None:
        old_state = self.__states.get(key)
        new_state = state.merge(old_state)
        self.__states[key] = new_state
        self.store_states()

    def get_state(self, key: K) -> State[V]:
        ret = self.__states.get(key)
        return State[V]() if ret is None else ret

    def _reset(self) -> None:
        "discards all in-memory states"
        self.__states = {}

    def _get_stored_keys(self) -> Iterable[K]:
        "yields all keys currently held in memory"
        return self.__states.keys()


class StateManagerImpl(
    StateManagerSingleImpl[K, V],
    StateManagerBackendImpl[K, V],
    ABC,
    Generic[K, V],
):
    "base class combining SingleManager views with a memory backend"


class SingleManagerImpl(SingleManager[V], Generic[K, V]):
    "SingleManager view onto one key of a StateManager"

    __mngr: StateManager[K, V]
    __key: K

    def __init__(self, mngr: StateManager[K, V], key: K) -> None:
        self.__mngr = mngr
        self.__key = key

    def submit_success(self, value: V) -> None:
        return self.submit(
            State(
                value=value,
                value_date=datetime.now(UTC),
            )
        )

    def submit_error(self, exc: Exception) -> None:
        return self.submit(
            State(
                error=exc,
                error_date=datetime.now(UTC),
            )
        )

    def submit(self, state: State[V]) -> None:
        return self.__mngr.submit_state(self.__key, state)

    @property
    def current_value(self) -> V:
        return self.current_state.current_value

    @property
    def current_state(self) -> State[V]:
        return self.__mngr.get_state(self.__key)


class StateSerializer(Generic[V]):
    "converts states to and from JSON-compatible values"

    def serialize(self, state: State[V]) -> JsonVal:
        "encodes a state into a JSON-compatible value"
        return {
            "value": state.value,
            "value_date": self.__serialize_date(state.value_date),
            "error": self.__serialize_exception(state.error),
            "error_date": self.__serialize_date(state.error_date),
        }

    def deserialize(self, data: JsonVal) -> State[V]:
        "decodes a JSON-compatible value back into a state"
        if not isinstance(data, dict):
            raise TypeError(f"expected dict, got {type(data).__name__}")
        return State(
            value=cast(V | None, data.get("value")),
            value_date=self.__deserialize_date(data.get("value_date")),
            error=self.__deserialize_exception(data.get("error")),
            error_date=self.__deserialize_date(data.get("error_date")),
        )

    @staticmethod
    def __serialize_date(d: datetime | None) -> str | None:
        "encodes a date as an ISO-formatted str"
        return None if d is None else d.isoformat()

    @staticmethod
    def __deserialize_date(d: JsonVal) -> datetime | None:
        "decodes an ISO-formatted str back into a date"
        if d is None:
            return None
        if not isinstance(d, str):
            raise TypeError(f"expected datetime.isoformat str, got {type(d).__name__}")
        return datetime.fromisoformat(d)

    @staticmethod
    def __serialize_exception(exc: Exception | str | None) -> str | None:
        "encodes an exception as a full traceback str"
        if not isinstance(exc, Exception):
            return exc
        return "".join(traceback.format_exception(exc))

    @staticmethod
    def __deserialize_exception(d: JsonVal) -> str | None:
        "decodes a traceback str back into an error"
        if d is None:
            return None
        if not isinstance(d, str):
            raise TypeError(f"expected error str, got {type(d).__name__}")
        return d
