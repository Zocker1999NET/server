#!/usr/bin/env bash

set -euxo pipefail

if [[ ! -e flake.nix ]]; then
    echo "missing flake.nix !!!" >&2
fi

orderedInputs="$(nix eval --raw --apply 'builtins.concatStringsSep " "' .#orderedInputs)"

for input in $orderedInputs; do
    nix flake update --commit-lock-file "$input"
done

# issue commit, if required
if ! git diff --exit-code; then
    git commit flake.lock -m "update flake.lock"
fi

exec ./tests.sh
