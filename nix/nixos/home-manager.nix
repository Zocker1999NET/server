# type: NixOS module
# manages integration of home-manager with flake & NixOS config
# TODO move into homeManagerModules
{
  config,
  flake,
  lib,
  ...
}:
let
  selfReference = ./home-maanger.nix;

  inherit (lib.lists) singleton;
  inherit (lib.modules) mkMerge;
in
{
  config.home-manager = mkMerge [

    # integration with flake
    {
      sharedModules = [
        flake.outputs.homeManagerModules.default
      ];
    }

    # integration with NixOS config
    {
      extraSpecialArgs = {
        inherit flake;
      };

      sharedModules = singleton {
        _file = selfReference;
        home.stateVersion = config.system.stateVersion;
      };

      useGlobalPkgs = true;
      useUserPackages = true;
    }

  ];
}
