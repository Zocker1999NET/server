#!/usr/bin/env bash

set -euo pipefail

if [[ ! -e flake.nix ]]; then
    echo "missing flake.nix !!!" >&2
fi

architecture="$( nix eval --impure --expr "builtins.currentSystem" )"
targetAttr=".#x-banananetwork_ci-targets.${architecture}"

# targets which are to be checked
targets=()

mapfile -t test_targets < <( nix eval --raw "${targetAttr}.testTargetsText" )
targets+=("${test_targets[@]}")

mapfile -t build_targets < <( nix eval --raw "${targetAttr}.buildTargetsText" )
targets+=("${build_targets[@]}")

rememberGC() {
    if [[ ${CI_GCROOT:-} == "" ]]; then
        return 0
    fi
    new_loc="$CI_GCROOT/$1"
    mv ./result "$new_loc"
    nix-store --add-root "$new_loc" --realise "$new_loc"
}

set -x

for target in "${targets[@]}"; do
    for i in 0 1 last; do
        if ./build_remote.sh "$@" .#"$target"; then
            rememberGC "$target"
            break  # continue outside
        elif [[ $i == "last" ]]; then
            echo "last attempt failed, forward error" >&2
            exit 1
        else
            echo "attempt no. $i failed, retry" >&2
        fi
    done
done
