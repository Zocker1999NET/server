#!/usr/bin/env bash

set -euo pipefail

if [[ ! -e flake.nix ]]; then
    echo "missing flake.nix !!!" >&2
fi

architecture="x86_64-linux"

# targets which are to be checked
targets=()

# tests which must succeed
test_targets=(
    "bind-dynamic"
    "docs_includeAllModules_banananetwork"
    "docs_includeAllModules_disko"
    "docs_includeAllModules_hm_banananetwork"
    "docs_includeAllModules_home-manager"
    "docs_includeAllModules_impermanence"
    "docs_includeAllModules_nixpkgs"
    "docs_includeAllModules_secrix"
    "empty"
    "getty-helpLine-sshPublicHostKey"
    "router"
    "router-tailscale"
)
for test_target in "${test_targets[@]}"; do
    targets+=("nixosTests.${architecture}.${test_target}")
done

# all configs must succeed (& are faster to be built remotely)
mapfile -t configs < <( nix eval --raw .#nixosConfigurations --apply 'a: with builtins; concatStringsSep "\n" (attrNames a)' )
for config in "${configs[@]}"; do
    targets+=("nixosConfigurations.\"${config}\".config.system.build.toplevel")
done
# last one to be available as result
targets+=("nixosConfigurations.mgmt-iso.config.system.build.isoImage")

set -x

for target in "${targets[@]}"; do
    ./build_remote.sh "$@" .#"$target"
done
