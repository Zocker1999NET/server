#!/usr/bin/env sh
exec nom build --option builders-use-substitutes true --builders "ssh-ng://nix-ssh@2a02:8071:7111:9510:be24:11ff:feb5:580c x86_64-linux /root/.ssh/id_ed25519 8 100 kvm,big-parallel,nixos-test" "$@"
