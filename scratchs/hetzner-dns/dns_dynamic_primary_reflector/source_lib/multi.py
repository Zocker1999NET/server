from __future__ import annotations

import random
import traceback
from collections import defaultdict
from collections.abc import (
    Hashable,
    Iterable,
    Sequence,
)
from dataclasses import (
    dataclass,
)
from typing import (
    Generic,
    TypeVar,
)

from .abstractions import (
    InfoSource,
    NonInfo,
    SourceReturn,
)

V = TypeVar("V", bound=Hashable)


@dataclass(
    frozen=True,
    kw_only=True,
    order=False,
    slots=True,
)
class MultiSource(InfoSource[V], Generic[V]):
    "queries layered sub-sources, requiring a unique consensus among their answers"

    sources: Sequence[Sequence[InfoSource[V]]]
    "layers of sub-sources, attempted front to back until requirements are met"
    random_order: bool = True
    "shuffle the sources within each layer on every retrieval"
    minimum: int = 1
    "number of uniform & successful answers required for consensus to be acceptable"
    max_uniform: int | None = None
    "given this number of uniform answers, accept immediately"
    warn_non_uniform: bool = True
    "emit a warning if sub-sources disagreed"
    accept_non_result: bool = False
    "count NO_RESULT answers as valid for the consensus"
    skip_exceptions: bool = True
    """skip raised exceptions (which indicate a bug)

    If True, this MultiSource continuous to work
    similar to the case of skip_errors,
    passing exception infos further as warnings.
    """
    skip_errors: bool = True
    """skip (expectable) errors in SourceReturn

    If True, error messages are passed as warnings,
    the error is interpreted as an empty info (even with accept_empty=True)
    and this MultiSource returns an info given
    its requirements are still fullfiled (e.g. minimum, unformity, …).
    """
    suppress_warnings: bool = False
    "suppress warnings of sub-sources"

    def retrieve_info(self) -> SourceReturn[V]:
        "queries sub-sources until acceptance is locked, then merges their answers"
        answers = list[SourceReturn[V]]()
        for src in self._sources_list():
            ans = self.__retrieve_from(src)
            if ans.error is not None and not self.skip_errors:
                # TODO integrate better
                return ans
            answers.append(ans)
            # no continue before this!
            if self._is_answer_locked(answers):
                break
        return self._merge_answers(answers)

    def __retrieve_from(self, source: InfoSource[V]) -> SourceReturn[V]:
        "retrieves from a single sub-source, converging exceptions to errors"
        if not self.skip_exceptions:
            # let exceptions pass right through
            return source.retrieve_info()
        # else catch them
        try:
            return source.retrieve_info()
        except Exception as err:
            return SourceReturn(
                source_name=source.source_name,
                info=NonInfo.NO_RESULT,
                error=f"[exception] {''.join(traceback.format_exception(err))}",
            )

    def _sources_list(self) -> Iterable[InfoSource[V]]:
        "yields all sub-sources, optionally shuffled within each layer"
        for sub_list in self.sources:
            sources = list(sub_list)
            if self.random_order:
                random.shuffle(sources)
            yield from sources

    def _is_answer_locked(self, answers: list[SourceReturn[V]]) -> bool:
        "True if further sub-source queries cannot change the outcome"
        sources_left = self._sources_count() - len(answers)
        if sources_left <= 0:
            return True
        info_sum = self._summarize_infos(answers)
        if len(info_sum) <= 0:
            return False
        best = info_sum[0][1]
        if best < self.minimum:
            return False
        if (
            self.max_uniform is not None
            and len(info_sum) <= 1
            and self.max_uniform <= best
        ):
            return True
        contender = info_sum[1][1] if len(info_sum) > 1 else 0
        return best > (contender + sources_left)

    def _sources_count(self) -> int:
        "total number of sub-sources across all layers"
        return sum(len(sub_list) for sub_list in self.sources)

    def _merge_answers(self, answers: list[SourceReturn[V]]) -> SourceReturn[V]:
        "aggregates all collected answers into a single consensus result"
        name = f"MultiSource( {', '.join(a.source_name for a in answers)} )"
        info_sum = self._summarize_infos(answers)
        error: str | None = None
        warnings = list[str]()
        print_answers = False
        if len(info_sum) <= 0:
            error = "no valid answer received"
        elif info_sum[0][1] < self.minimum:
            error = f"minimum consent of {self.minimum} not reached"
        elif len(info_sum) > 1 and info_sum[0][1] <= info_sum[1][1]:
            error = "majority is not unique"
        else:
            if self.warn_non_uniform and len(info_sum) > 1:
                warnings.append("non uniform answers received")
                print_answers = True
        print_answers = error is not None or print_answers
        warnings.extend(
            self._summarize_warnings(
                answers,
                print_answers=print_answers,
            )
        )
        return SourceReturn(
            source_name=name,
            info=info_sum[0][0] if error is None else NonInfo.NO_RESULT,
            error=error,
            warnings=warnings,
        )

    def _summarize_infos(
        self,
        answers: list[SourceReturn[V]],
    ) -> Sequence[tuple[V | NonInfo, int]]:
        "counts valid answers per distinct info, sorted by frequency"
        info_counter = defaultdict[V | NonInfo, int](lambda: 0)
        for a in answers:
            if self._is_answer_valid(a):
                info_counter[a.info] += 1
        return sorted(info_counter.items(), key=lambda a: (-a[1], a[0]))

    def _summarize_warnings(
        self,
        answers: list[SourceReturn[V]],
        print_answers: bool,
    ) -> Iterable[str]:
        "yields consolidated warnings of all answers"
        for a in answers:
            if print_answers and self._is_answer_valid(a):
                yield f"{a.source_name} returned: {a.info!r}"
            if a.error is not None:
                yield f"{a.source_name} failed: {a.error}"
            if not self.suppress_warnings:
                yield from (f"{a.source_name}: {txt}" for txt in a.warnings)

    def _is_answer_valid(self, answer: SourceReturn[V]) -> bool:
        "True if the answer may contribute to the consensus"
        return answer.error is None and (
            answer.info is not NonInfo.NO_RESULT or self.accept_non_result
        )

    @property
    def source_name(self) -> str:
        return f"MultiSource( {', '.join(src.source_name for level in self.sources for src in level)} )"
