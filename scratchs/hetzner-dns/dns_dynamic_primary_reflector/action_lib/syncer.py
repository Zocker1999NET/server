from __future__ import annotations

from enum import (
    Enum,
    auto,
)
from typing import (
    Generic,
    TypeVar,
)

from .abs import (
    Action,
    SimpleSource,
    SourceError,
)
from .state import (
    StateSupervisor,
)
from ..state_lib import (
    SingleManager,
)
from ..type_lib import (
    InfoVal,
)


V = TypeVar("V", bound=InfoVal)


class SyncResult(Enum):
    "outcome of one synchronization attempt"

    UPDATE_SUCCESS = auto()
    "a changed value was applied successfully"
    UPDATE_ERROR = auto()
    "applying the changed value failed"
    SOURCE_ERROR = auto()
    "the source failed to provide a value"
    ALREADY_SYNC = auto()
    "value unchanged since the last successful update"

    @property
    def process_error(self) -> bool:
        "True if this outcome should abort further processing"
        return self == SyncResult.UPDATE_ERROR

    @staticmethod
    def from_attempted_update(result: bool) -> SyncResult:
        "maps a supervisor update outcome to a sync result"
        return SyncResult.UPDATE_SUCCESS if result else SyncResult.UPDATE_ERROR


class StateSyncer(Generic[V]):
    "keeps the applied value synchronized with the source's current value"

    __source: SimpleSource[V]
    "provides the expected value"
    __supervisor: StateSupervisor[V]
    "applies values to the target"

    def __init__(
        self,
        action: Action[V],
        source_state: SimpleSource[V],
        target_state: SingleManager[V],
    ) -> None:
        "wires a source, an action and its persistent target state together"
        self.__source = source_state
        self.__supervisor = StateSupervisor(state=target_state, action=action)

    def sync_raise(self) -> SyncResult:
        "synchronizes once, raising on an update error"
        res = self.attempt_sync()
        if res.process_error and self.last_error is not None:
            raise self.last_error
        return res

    def attempt_sync(self) -> SyncResult:
        "performs one synchronization attempt, reporting its outcome"
        try:
            expected = self.expected_value
        except SourceError:
            return SyncResult.SOURCE_ERROR
        if expected == self.current_value:
            return SyncResult.ALREADY_SYNC
        update_res = self.__supervisor.attempt_update(expected)
        return SyncResult.from_attempted_update(update_res)

    @property
    def last_error(self) -> Exception | None:
        "error of the most recent failed update, if any"
        return self.__supervisor.last_error

    @property
    def expected_value(self) -> V:
        "value the source currently provides"
        return self.__source.current_value

    @property
    def current_value(self) -> V | None:
        "last value successfully applied to the target, if any"
        return self.__supervisor.current_value

    @property
    def is_synchronized(self) -> bool:
        "True if source and target currently agree"
        return self.__source.current_value == self.__supervisor.current_value
