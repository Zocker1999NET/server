#!/usr/bin/env bash

set -euxo pipefail

if [[ ! -e flake.nix ]]; then
    echo "missing flake.nix !!!" >&2
fi

# targets which are to be checked
targets=(
    # tests which must succeed
    "nixosTests.x86_64-linux.bind-dynamic"
    "nixosTests.x86_64-linux.docs_includeAllModules_banananetwork"
    "nixosTests.x86_64-linux.docs_includeAllModules_disko"
    "nixosTests.x86_64-linux.docs_includeAllModules_hm_banananetwork"
    "nixosTests.x86_64-linux.docs_includeAllModules_home-manager"
    "nixosTests.x86_64-linux.docs_includeAllModules_impermanence"
    "nixosTests.x86_64-linux.docs_includeAllModules_nixpkgs"
    "nixosTests.x86_64-linux.docs_includeAllModules_secrix"
    "nixosTests.x86_64-linux.empty"
    "nixosTests.x86_64-linux.getty-helpLine-sshPublicHostKey"
    "nixosTests.x86_64-linux.router"
    "nixosTests.x86_64-linux.router-tailscale"
    # images which also must built (& are faster to be built remotely)
    "nixosConfigurations.x13yz.config.system.build.toplevel"
    # last one to be available as result
    "nixosConfigurations.mgmt-iso.config.system.build.isoImage"
)

for target in "${targets[@]}"; do
    nom build --option builders-use-substitutes true --builders "ssh://iehadmin@iehsrv995.ieh.kit.edu x86_64-linux /root/.ssh/id_ed25519 8 100 kvm,big-parallel,nixos-test" .#"$target"
done
