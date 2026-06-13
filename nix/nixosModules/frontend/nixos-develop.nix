# parts of my frontend NixOS module
# only applicable to machines used for developing stuff (currently all)
{
  config,
  flake,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.x-banananetwork.frontend;
  inherit (lib.modules) mkIf;
in
{

  _class = "nixos";

  config = mkIf cfg.enable {

    # TODO reenable, taskwarrior:///d3d19597-a834-4030-9f42-4e8fac56daac
    documentation.nixos.includeAllModules = false; # full manual aids NixOS dev

    programs = {

      firejail.enable = true;

    };

    x-banananetwork.cachedFlakesDevShell = [
      flake
    ];

  };
}
