{
  lib,
  flake-parts-lib,
  moduleLocation,
  ...
}:
let
  self_reference = ./nixosTests.nix;

  inherit (builtins) mapAttrs;
  inherit (lib) types;
  inherit (lib.attrsets) mapAttrs' nameValuePair;
  inherit (lib.modules) mkDefault;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) flip;
  inherit (flake-parts-lib) mkPerSystemOption;
in
{

  _class = "flake";

  options.perSystem = mkPerSystemOption {
    _file = self_reference;
    options.nixosTests = mkOption {
      description = ''
        Allows simple definitions of checks
        which run a NixOS test
        as defined by the given module.

        To define a test with this option,
        submit a nixosTest module under one unique attribute.

        The name of the attr is reflected into the NixOS test module as a mkDefault value.
      '';
      type = with types; lazyAttrsOf deferredModule;
      default = { };
      apply = mapAttrs (
        k: v: {
          _class = "nixosTest";
          _file = "${toString moduleLocation}#nixosModules.${k}";
          config.name = mkDefault k;
          imports = [ v ];
        }
      );
    };
  };

  config.perSystem =
    { config, pkgs, ... }:
    {
      checks = flip mapAttrs' config.nixosTests (
        name: value: nameValuePair "nixosTests:${name}" (pkgs.testers.runNixOSTest value)
      );
    };

}
