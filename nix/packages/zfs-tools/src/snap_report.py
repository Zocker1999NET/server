#!/usr/bin/env python3

from __future__ import annotations

import argparse
from collections.abc import (
    Sequence,
    Iterable,
)
from dataclasses import dataclass
import subprocess


def zfs_split_snap_name(full_name: str) -> tuple[str, str | None]:
    if "@" not in full_name:
        return full_name, None
    set_name, snap_name = full_name.split("@", 1)
    return set_name, snap_name


def zfs_list(*args: str) -> Iterable[Sequence[str]]:
    cmd = [
        "/usr/bin/env",
        "zfs",
        "list",
        "-H",  # remove table headers, use simple tab separation
        "-p",  # make numbers parseable
    ] + list(args)
    proc = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, text=True)
    for line in proc.stdout.splitlines():
        yield line.split("\t")


@dataclass
class DatasetInfo:
    name: str
    written: int
    last_snap: str | None = None

    @property
    def snap_info(self) -> str:
        if self.last_snap is None:
            return "(no snapshot)"
        if self.written != 0:
            return f"* {self.last_snap}"
        return self.last_snap


def format_dataset_info(info: DatasetInfo) -> Sequence[str]:
    return info.name, info.snap_info


def get_dataset_infos(zfs_args: tuple[str, ...]) -> Iterable[DatasetInfo]:
    data = zfs_list("-o", "name,written", "-t", "filesystem,volume,snapshot", *zfs_args)
    info: DatasetInfo | None = None
    for line in data:
        assert len(line) == 2
        full_name, written = line
        set_name, snap_name = zfs_split_snap_name(full_name)
        if info is None or info.name != set_name:
            assert snap_name is None, f"missing line without snap for: {set_name}"
            if info is not None:
                yield info
            info = DatasetInfo(name=set_name, written=int(written))
        else:
            assert snap_name is not None, f"duplicated line with: {full_name}"
            info.last_snap = snap_name
    if info is not None:
        yield info


def pretty_format(content: Sequence[Sequence[str]]) -> str:
    transposed = zip(*content)
    max_lengths = [max(len(c) for c in b) for b in transposed]
    max_lengths[-1] = 0  # last column requires no spacing
    return "\n".join(
        "  ".join(val.ljust(col_len) for col_len, val in zip(max_lengths, line))
        for line in content
    )


@dataclass(frozen=True)
class UserArgs:
    zfs_args: tuple[str, ...]


def parse_args() -> UserArgs:
    parser = argparse.ArgumentParser()
    parser.add_argument("-r", "--recursive", action="store_true")
    parser.add_argument("dataset", nargs="*")
    args = parser.parse_args()

    def translate() -> Iterable[str]:
        if args.recursive:
            yield "-r"
        yield "--"  # separate options & dataset names
        yield from args.dataset

    return UserArgs(
        zfs_args=tuple(translate()),
    )


def main() -> None:
    user = parse_args()
    dataset_infos = get_dataset_infos(user.zfs_args)
    formatted = map(format_dataset_info, dataset_infos)
    pretty = pretty_format(tuple(formatted))
    print(pretty)


if __name__ == "__main__":
    main()
