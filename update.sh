#!/usr/bin/env bash

set -euxo pipefail

if [[ ! -e flake.nix ]]; then
    echo "missing flake.nix !!!" >&2
fi

# I update those without checking the changelogs
nix flake update nixpkgs nixpkgs_unstable disko home-manager impermanence nixos-hardware disko-install-menu

# issue commit, if required
if ! git diff --exit-code; then
    git commit flake.lock -m "update flake.lock"
fi

exec ./tests.sh
