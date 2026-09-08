# Enables QEMU-based binfmt emulation for all architectures present in this flake's nixosConfigurations,
# which keeps builds compatible with the nixpkgs binary cache.
#
# See: https://nixos-and-flakes.thiscute.world/development/cross-platform-compilation#compile-through-emulated-system
{
  config,
  flake,
  lib,
  ...
}:
let
  inherit (builtins) attrValues filter;
  inherit (lib.lists) unique;
  inherit (lib.trivial) pipe;

  getNixosSystem = config: config.nixpkgs.localSystem.system;
in
{
  _class = "nixos";
  config.boot.binfmt.emulatedSystems = pipe (flake.outputs.nixosConfigurations or { }) [
    attrValues
    (map (cfg: getNixosSystem cfg.config))
    unique
    (filter (system: system != getNixosSystem config))
  ];
}
