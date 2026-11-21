from __future__ import annotations

import json
from collections.abc import Sequence
from pathlib import Path

from .abstractions import (
    K,
    V,
)
from .utils import (
    StateManagerImpl,
    StateSerializer,
)


class FileStateManager(StateManagerImpl[K, V]):
    "persists states as JSON under the first existing of several candidate paths"

    __paths: tuple[Path, ...]
    "candidate storage paths in priority order"
    __new_path_idx: int
    "candidate index to use when none exists yet"
    __create_dir: bool
    "create missing parent directories on write"
    __check_for_dir_only: bool
    "match candidates by their parent directory instead"
    __serializer: StateSerializer[V]
    "converts states to and from JSON"

    def __init__(
        self,
        paths: Sequence[Path],
        new_path_idx: int = 0,
        create_dir: bool = True,
        check_for_dir_only: bool = False,
    ) -> None:
        super().__init__()
        self.__paths = tuple(paths)
        self.__new_path_idx = new_path_idx
        self.__create_dir = create_dir
        self.__check_for_dir_only = check_for_dir_only
        self.__serializer = StateSerializer()

    def store_states(self) -> None:
        "writes all known states as JSON to the selected path"
        path = self.__canonical_path
        if self.__create_dir:
            path.parent.mkdir(parents=True, exist_ok=True)
        data = {
            key: self.__serializer.serialize(self.get_state(key))
            for key in self._get_stored_keys()
        }
        with path.open("w") as fh:
            json.dump(data, fh)

    def load_states(self) -> None:
        "replaces all in-memory states with those read from the selected path"
        path = self.__canonical_path
        self._reset()
        if not path.exists():
            return
        with path.open("r") as fh:
            data = json.load(fh)
        if not isinstance(data, dict):
            raise TypeError(
                f"while reading {path} as JSON, expected dict, got {type(data).__name__}"
            )
        for key, state in data.items():
            self.submit_state(key, self.__serializer.deserialize(state))

    @property
    def __canonical_path(self) -> Path:
        "first candidate path (or parent dir) that exists, else the initial one"
        for path in self.__paths:
            check = path.parent if self.__check_for_dir_only else path
            if check.exists():
                return path
        return self.__paths[self.__new_path_idx]
