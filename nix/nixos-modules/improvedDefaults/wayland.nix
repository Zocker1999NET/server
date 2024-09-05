{
  config,
  lib,
  pkgs,
  ...
}:
let
  prgs = config.programs;
  servDM = config.services.desktopManager;
  xDM = config.services.xserver.desktopManager;
  cfg = config.x-banananetwork.improvedDefaults;
in
{

  options = {

    services.wayland.enable = lib.mkEnableOption ''
      sensible defaults for Wayland sessions.

      Be aware that a Wayland compositor or desktop environment is not enabled automatically
      as there is no main implementation of Wayland.
    '';

  };

  config = lib.mkMerge [

    (lib.mkIf (cfg.enable) {
      # auto detect if a wayland compatible compositor is already enabled
      services.wayland.enable = builtins.any (x: x) ([
        prgs.hyprland.enable
        prgs.miriway.enable
        prgs.river.enable
        prgs.sway.enable
        prgs.wayfire.enable
        (xDM.mate.enable && xDM.mate.enableWaylandSession)
        servDM.lomiri.enable # unsure wheather this is using Wayland
        servDM.plasma6.enable
      ]);
    })

    (lib.mkIf (config.services.wayland.enable) {

      # TODO mirror on home-manager
      environment.sessionVariables = {
        MOZ_ENABLE_WAYLAND = lib.mkIf config.programs.firefox.enable "1";
        NIXOS_OZONE_WL = "1";
      };

      # make Steam Input events possible
      programs.steam.extest.enable = lib.mkIf config.programs.steam.enable true;

      warnings = lib.mkIf (xDM.mate.enable && !xDM.mate.enableWaylandSession) [
        "Wayland & Mate are enabled, but Mate‘s Wayland support is disabled, you should enable services.xserver.displayManager.enableWaylandSession"
      ];

    })

  ];

}
