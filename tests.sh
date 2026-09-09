#!/usr/bin/env bash

set -euo pipefail

if [[ ! -e flake.nix ]]; then
    echo "missing flake.nix !!!" >&2
fi

AUTO_BISECT_GOOD=""  # good commit for git bisect on failure
GREP_FILTER=""
RANDOM_ORDER=""  # useful for quicker mass-bug-detecting on release upgrades
PRINT_OUT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --auto-bisect)
            AUTO_BISECT_GOOD="$2"
            shift 2
            ;;
        --grep)
            GREP_FILTER="$2"
            shift 2
            ;;
        --print-out)
            PRINT_OUT="y"
            shift 1
            ;;
        --random-order)
            RANDOM_ORDER="y"
            shift 1
            ;;
        *)
            echo "unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

filter() {
    if [[ -n "$GREP_FILTER" ]]; then
        grep "$GREP_FILTER"
    elif [[ -n "$RANDOM_ORDER" ]]; then
        shuf
    else
        cat
    fi
}

architecture="$( nix eval --impure --expr "builtins.currentSystem" )"
targetAttr=".#x-banananetwork_ci-targets.${architecture}"

# targets which are to be checked
targets=()

mapfile -t test_targets < <( nix eval --raw "${targetAttr}.testTargetsText" | filter )
targets+=("${test_targets[@]}")

mapfile -t build_targets < <( nix eval --raw "${targetAttr}.buildTargetsText" | filter )
targets+=("${build_targets[@]}")

if [[ -n "$PRINT_OUT" ]]; then
    echo "would build following targets:"
    for target in "${targets[@]}"; do
        echo "  - $target"
    done
    exit 0
fi

# - checks.* often have empty outputs or at least small ones
#   - checks are e.g. NixOS tests
# -> holding a GC root for them indefinitely is cheap
# -> prevents rebuilding the same check target in the future
#   - e.g. on a git bisect, where historic commits are rechecked
# - other builds are separated s.t. only their latest build is kept, to save space
#   - other builds are e.g. devShells.*, nixosConfigurations.*, packages.*, …
is_test_target() {
    case "$1" in
        checks.*) return 0 ;;
        *) return 1 ;;
    esac
}

rememberGC() {
    if [[ ${CI_GCROOT:-} == "" ]]; then
        return 0
    fi
    local target="$1"
    local commit
    if ! commit="$(git rev-parse --short HEAD 2>/dev/null)"; then
        echo "rememberGC: cannot determine commit hash (not in a git repo?)" >&2
        return 1
    fi
    local new_loc
    if is_test_target "$target"; then
        new_loc="$CI_GCROOT/checks/$commit/$target"
    else
        new_loc="$CI_GCROOT/builds/$commit/$target"
    fi
    mkdir -p "$(dirname "$new_loc")"
    mv ./result "$new_loc"
    nix-store --add-root "$new_loc" --realise "$new_loc"
}

# git bisect the failure of a single target to its first failing commit.
# Suppresses the output of all bisect actions except `git bisect run`,
# prints the found hash, and resets the bisect as the last command.
bisect_failure() {
    local target="$1"
    local test_runner="./build_remote.sh .#\"$target\" >/dev/null"
    echo "attempt bisecting error" >&2
    git bisect reset >/dev/null
    git bisect start >/dev/null
    git bisect bad HEAD >/dev/null
    git bisect good "$AUTO_BISECT_GOOD" >/dev/null
    git bisect run bash -c "$test_runner"
    echo "auto-bisect: first failing commit: $(git rev-parse --short HEAD)"
    git bisect reset >/dev/null
}

set -x

for target in "${targets[@]}"; do
    for i in 0 1 last; do
        if ./build_remote.sh "$@" .#"$target"; then
            rememberGC "$target"
            break  # continue outside
        elif [[ $i == "last" ]]; then
            echo "last attempt failed, forward error" >&2
            if [[ -n "$AUTO_BISECT_GOOD" ]]; then
                bisect_failure "$target"
            fi
            exit 1
        else
            echo "attempt no. $i failed, retry" >&2
        fi
    done
done
