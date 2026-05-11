# type: NixOS module
# manages integration of home-manager with flake & NixOS config
# TODO move into homeModules
{
  config,
  flake,
  flakeArg,
  lib,
  ...
}:
let
  selfReference = ./home-manager.nix;

  inherit (lib.lists) singleton;
  inherit (lib.modules) mkMerge;
in
{
  _class = "nixos";
  config.home-manager = mkMerge [

    # integration with flake
    {
      sharedModules = [
        flake.outputs.homeModules.default
      ];
    }

    # integration with NixOS config
    {
      extraSpecialArgs = flakeArg.config.flakeSpecialArgs;

      sharedModules = singleton {
        _file = selfReference;
        home.stateVersion = config.system.stateVersion;
      };

      useGlobalPkgs = true;
      useUserPackages = true;
    }

  ];
}
