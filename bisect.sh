#!/usr/bin/env bash

set -euo pipefail


if [[ $# -lt 1 ]]; then
    echo "usage: $0 <good-commit-sha> [<test>]" >&2
    echo " HEAD is assumed as bad commit" >&2
    echo " if test is not given, all tests will be executed" >&2
    exit 1
fi


good_commit="$1"

if [[ $# -lt 2 ]]; then
    echo "no test defined, execute all tests"
    test_runner="./tests.sh"
else
    echo "execute only: $2"
    test_name=".#checks.x86_64-linux.$2"
    test_runner="./build_remote.sh $test_name"
fi


set -x

git bisect reset
git bisect start
git bisect bad HEAD
git bisect good "$good_commit"
git bisect run $test_runner
