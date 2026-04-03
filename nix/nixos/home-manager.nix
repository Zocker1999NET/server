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

  inherit (lib.modules) mkMerge;
in
{
  config.home-manager = mkMerge [

    # integration with flake
    {
      sharedModules = [
        {
          _file = selfReference;
          _module.args = {
            inherit flake;
          };
        }
        flake.outputs.homeManagerModules.default
      ];
    }

  ];
}
