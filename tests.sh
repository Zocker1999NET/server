#!/usr/bin/env bash

set -euo pipefail

if [[ ! -e flake.nix ]]; then
    echo "missing flake.nix !!!" >&2
fi

architecture="x86_64-linux"

# targets which are to be checked
targets=()

# all checks must succeed
mapfile -t test_targets < <( nix eval --raw ".#checks.${architecture}" --apply 'a: with builtins; concatStringsSep "\n" (attrNames a)' )
for test_target in "${test_targets[@]}"; do
    targets+=("checks.${architecture}.${test_target}")
done

# all configs must succeed (& are faster to be built remotely)
mapfile -t configs < <( nix eval --raw .#nixosConfigurations --apply 'a: with builtins; concatStringsSep "\n" (attrNames a)' )
for config in "${configs[@]}"; do
    targets+=("nixosConfigurations.\"${config}\".config.system.build.toplevel")
done

# all devShells must succeed
mapfile -t devshells < <( nix eval --raw ".#devShells.${architecture}" --apply 'a: with builtins; concatStringsSep "\n" (attrNames a)' )
for devshell in "${devshells[@]}"; do
    targets+=("devShells.${architecture}.${devshell}")
done

# last one to be available as result
targets+=("nixosConfigurations.mgmt-iso.config.system.build.isoImage")

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
