# derived from https://github.com/hercules-ci/flake-parts/blob/main/modules/nixosModules.nix
{
  lib,
  moduleLocation,
  ...
}:
let
  inherit (lib)
    mapAttrs
    mkOption
    types
    ;
in
{
  _class = "flake";
  options = {
    flake.nixosProfiles = mkOption {
      type = types.lazyAttrsOf types.deferredModule;
      default = { };
      apply = mapAttrs (
        k: v: {
          _class = "nixos";
          _file = "${toString moduleLocation}#nixosProfiles.${k}";
          imports = [ v ];
        }
      );
      description = ''
        NixOS profiles.

        Functionally the same as nixosModules,
        but intended for classes of shared configurations,
        which are mainly intended to be used exclusively.
      '';
    };
  };
}
