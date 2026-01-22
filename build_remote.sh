#!/usr/bin/env bash

set -euo pipefail

if [[ ${CI_MODE:-} != "" ]]; then
    exec nix build "$@"
fi

cmd="nix"
if command -v nom &>/dev/null; then
    cmd="nom"
fi

exec "$cmd" build --option builders-use-substitutes true --builders "ssh-ng://nix-ssh@fde3:b424:b5ce:1:be24:11ff:fe1d:8e2e x86_64-linux /root/.ssh/id_ed25519 8 100 kvm,big-parallel,nixos-test ; ssh://iehadmin@iehsrv995.ieh.kit.edu x86_64-linux /root/.ssh/id_ed25519 32 100 kvm,big-parallel,nixos-test" "$@"
