from __future__ import annotations

from dataclasses import (
    dataclass,
)
from typing import (
    TypeVar,
)

from ..state_lib import (
    SingleManager,
)
from ..type_lib import (
    InfoVal,
)
from .abs import (
    Action,
    UpdateSupervisor,
)

V = TypeVar("V", bound=InfoVal)


@dataclass(
    frozen=True,
    kw_only=True,
)
class StateSupervisor(UpdateSupervisor[V]):
    "records action outcomes in a persistent state"

    state: SingleManager[V]
    "where outcomes are recorded"
    action: Action[V]
    "performs the actual update"

    def attempt_update(self, data: V) -> bool:
        try:
            self.action.update(data)
        except Exception as exc:
            self.state.submit_error(exc)
            return False
        self.state.submit_success(data)
        return True

    @property
    def last_error(self) -> Exception | None:
        exc = self.state.current_state.error
        return exc if isinstance(exc, Exception) else None

    @property
    def current_value(self) -> V | None:
        return self.state.current_state.value
