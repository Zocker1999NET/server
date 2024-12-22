from __future__ import annotations

from argparse import (
    ArgumentParser,
    Namespace,
)
import logging
from pathlib import Path
import os

from systemd.journal import JournalHandler  # type: ignore[import-untyped]

from .argparse_ext import ArgumentParserDecorator


LOG_LEVEL_MAP = {
    "critical": logging.CRITICAL,
    "error": logging.ERROR,
    "warning": logging.WARNING,
    "info": logging.INFO,
    "debug": logging.DEBUG,
}


class LogMgr(ArgumentParserDecorator):
    "purposefully built for my applications"

    def __init__(self, name: str | None = None) -> None:
        "name is 1:1 given to logging.getLogger, so it should be '__name__' in most cases"
        self.__logger = logging.getLogger(name)

    def setup_args(self, parser: ArgumentParser) -> None:
        parser.add_argument(
            "-l",
            "--log-level",
            default="error",
            choices=LOG_LEVEL_MAP.keys(),
            help="Log level for outputs to stdout/stderr (ignored when launched in a systemd service)",
        )

    def on_parsing(self, args: Namespace) -> None:
        # INVOCATION_ID set by systemd, see man systemd.exec(5)
        # /dev/log is created by systemd-journald
        systemd_service = os.environ.get("INVOCATION_ID") and Path("/dev/log").exists()
        if systemd_service:
            self.logger.setLevel(logging.DEBUG)
            self.logger.addHandler(
                JournalHandler(SYSLOG_IDENTIFIER="nft-update-addresses")
            )
        else:
            logging.basicConfig()  # get output to stdout/stderr
            self.logger.setLevel(LOG_LEVEL_MAP[args.log_level])

    @property
    def logger(self) -> logging.Logger:
        return self.__logger
