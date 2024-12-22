# Generic Update Handler Stuff


from __future__ import annotations

from abc import (
    ABC,
    abstractmethod,
)
from collections.abc import (
    Sequence,
)
import logging
import os
import threading
from threading import (
    RLock,
    Timer,
)
import traceback
from typing import (
    Any,
    Protocol,
    TypeVar,
)

from attrs import (
    define,
    field,
)

from pathlib import Path


logger = logging.getLogger(__name__)


def raise_and_exit(args: Any) -> None:
    Timer(0.01, os._exit, args=(1,)).start()
    logger.error(repr(args.exc_value))
    logger.error(
        "\n".join(traceback.format_tb(args.exc_traceback))
        if args.exc_traceback != None
        else "traceback from thread got lost!"
    )
    raise args.exc_value or Exception(f"{args.exc_type} (exception details got lost)")


# ensure exceptions in any thread brings the program down
# important for proper error detection via tests & in random cases in real world

threading.excepthook = raise_and_exit


T = TypeVar("T", contravariant=True)


class UpdateHandler(Protocol[T]):
    def update(self, data: T) -> None: ...

    def update_stack(self, data: Sequence[T]) -> None: ...


class UpdateStackHandler(UpdateHandler[T], ABC):
    def update(self, data: T) -> None:
        return self._update_stack((data,))

    def update_stack(self, data: Sequence[T]) -> None:
        if len(data) <= 0:
            logger.warning(
                f"[bug, please report upstream] received empty data in update_stack. Traceback:\n{''.join(traceback.format_stack())}"
            )
            return
        return self._update_stack(data)

    @abstractmethod
    def _update_stack(self, data: Sequence[T]) -> None: ...


class IgnoreHandler(UpdateStackHandler[object]):
    def _update_stack(self, data: Sequence[object]) -> None:
        return


@define(
    kw_only=True,
    slots=False,
)
class UpdateBurstHandler(UpdateStackHandler[T]):
    burst_interval: float
    handler: Sequence[UpdateHandler[T]]
    __lock: RLock = field(factory=RLock)
    __updates: list[T] = field(factory=list)
    __timer: Timer | None = None

    def _update_stack(self, data: Sequence[T]) -> None:
        with self.__lock:
            self.__updates.extend(data)
            self.__refresh_timer()

    def __refresh_timer(self) -> None:
        with self.__lock:
            if self.__timer is not None:
                # try to cancel
                # not a problem if timer already elapsed but before processing really started
                # because due to using locks when accessing updates
                self.__timer.cancel()
            self.__timer = Timer(
                interval=self.burst_interval,
                function=self.__process_updates,
            )
            self.__timer.start()

    def __process_updates(self) -> None:
        with self.__lock:
            self.__timer = None
            if not self.__updates:
                return
            updates = self.__updates
            self.__updates = []
        for handler in self.handler:
            handler.update_stack(updates)
