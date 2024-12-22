from __future__ import annotations

from argparse import (
    ArgumentParser,
    Namespace,
)
from typing import (
    Protocol,
)


class ArgumentParserDecorator(Protocol):

    def setup_args(self, parser: ArgumentParser) -> None: ...

    def on_parsing(self, args: Namespace) -> None: ...


class ArgumentParserExtender:
    __parser: ArgumentParser
    __extensions: list[ArgumentParserDecorator]

    @staticmethod
    def init(
        parser: ArgumentParser,
        *extensions: ArgumentParserDecorator,
    ) -> ArgumentParser:
        "syntactic sugar for daily usage"
        extender = ArgumentParserExtender(parser)
        extender.decorate(*extensions)
        return extender.parser

    def __init__(self, parser: ArgumentParser) -> None:
        self.__parser = parser  # delibriatly no default to incentive explicit usage
        self.__extensions = list()

    def parse_args(self) -> Namespace:
        args = self.__parser.parse_args()
        for ext in self.__extensions:
            ext.on_parsing(args)
        return args

    def decorate(self, *extensions: ArgumentParserDecorator) -> None:
        for ext in extensions:
            self.__decorate(ext)

    def __decorate(self, extension: ArgumentParserDecorator) -> None:
        extension.setup_args(self.__parser)
        self.__extensions.append(extension)

    @property
    def parser(self) -> ArgumentParser:
        return self.__parser
