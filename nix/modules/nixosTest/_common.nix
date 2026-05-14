# miscellaneous collection of some stuff I expect
{
  flakeArg,
  lib,
  ...
}:
let
  inherit (lib.modules) mkDefault;
in
{
  _class = "nixosTest";
  config = {

    defaults =
      { pkgs, ... }:
      {
        # packages for testing
        environment.systemPackages = with pkgs; [
          curl
          dig
          jq
        ];
        # prefer networkd
        networking.useNetworkd = mkDefault true;
      };

    node = {
      # allow individual nixpkgs (and so overlays) per node
      # induces extra evaluation time as nixpkgs needs to be evaluated per node
      # TODO rebuild test infrastructure to not rely on this
      pkgsReadOnly = false;
      specialArgs = flakeArg.config.flakeSpecialArgs;
    };

  };
}
