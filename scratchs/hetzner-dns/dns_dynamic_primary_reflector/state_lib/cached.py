from __future__ import annotations

import logging
from dataclasses import (
    dataclass,
)
from typing import (
    Generic,
    TypeVar,
)

from ..action_lib import (
    SimpleSource,
    SourceError,
)
from ..type_lib import (
    InfoVal,
)
from .abstractions import (
    SingleManager,
)

V = TypeVar("V", bound=InfoVal)

logger = logging.getLogger(__name__)


@dataclass(
    frozen=True,
    order=False,
    slots=True,
)
class CachedSource(SimpleSource[V], Generic[V]):
    """Wraps a ``SimpleSource`` (the live IP-discovery chain) and persists its
    last-good value through a :class:`SingleManager` (backed by a
    :class:`StateManager`).

    * on a successful measurement the freshly obtained value is persisted,
    * if a later measurement fails (e.g. the network is down), the last cached
      value is served instead — as long as one exists.

    This lets discovered IPs survive restarts and flaky upstreams: a transient
    outage no longer downgrades into an error for the downstream sync.
    """

    source: SimpleSource[V]
    "the live value source to cache"
    state: SingleManager[V]
    "storage for the last good value"

    @property
    def current_value(self) -> V:
        try:
            value = self.source.current_value
        except SourceError as exc:
            cached = self.state.current_state
            if cached.has_any_value and cached.value is not None:
                logger.warning(
                    "%s: %s; serving cached value", exc.source_name, exc.error_msg
                )
                return cached.value
            self.state.submit_error(exc)
            raise
        self.state.submit_success(value)
        return value
