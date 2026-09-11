#!/usr/bin/env bash

set -euo pipefail

if [[ ${CI_MODE:-} != "" ]]; then
    if nix build "$@"; then
        exit 0
    else
        rc=$?
        # detect missing target attribute
        if ( set +o pipefail; nix eval --raw "$@" 2>&1 | grep -q "does not provide attribute" ); then
            # skip commit for git bisect
            exit 125
        fi
        exit $rc
    fi
fi

if [[ ${1:-} == "--eval" ]]; then
    shift 1
    msg=$(nix eval "$@")
    r="$?"
    echo "$msg"
    if ! <<<"$msg" grep --fixed-string "derivation /nix/store/" >/dev/null; then
        echo "error from $0: eval failed to output derivation path" >&2
        exit 1;
    fi
    exit "$r";
fi

cmd="nix"
if command -v nom &>/dev/null; then
    cmd="nom"
fi

# used to always get the builders configs from this flake, even if run from different cwd or with different flake's build target
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

get_supported_systems() {
    local config_name="$1"
    nix eval --raw "$script_dir#nixosConfigurations.\"$config_name\".config.nix.supportedBuildSystemsConcat"
}

# Associative array: name -> builder config
declare -A builder_configs
builder_configs["nix-builder"]="ssh-ng://nix-ssh@fde3:b424:b5ce:1:be24:11ff:feb5:580c $(get_supported_systems nix-builder.boreth.pve.6nw.de) /root/.ssh/id_ed25519 8 100 kvm,big-parallel,nixos-test"
builder_configs["iehsrv995"]="ssh-ng://nix-ssh@iehsrv995.ieh.kit.edu $(get_supported_systems iehsrv995) /root/.ssh/id_ed25519 32 100 kvm,big-parallel,nixos-test"

# Build the builders string based on --only-builders filter (must be first argument)
if [[ "${1:-}" == "--only-builders" ]]; then
    IFS=',' read -ra selected <<< "$2"
    shift 2
else
    selected=("${!builder_configs[@]}")
fi
builders=""
for builder in "${selected[@]}"; do
    if [[ -v "builder_configs[$builder]" ]]; then
        if [[ -n "$builders" ]]; then
            builders+=$'\n'
        fi
        builders+="${builder_configs[$builder]}"
    else
        echo "Error: Unknown builder '$builder'" >&2
        exit 1
    fi
done

exec "$cmd" build \
    --option always-allow-substitutes true \
    --option builders-use-substitutes true \
    --builders "$builders" \
    "$@"
