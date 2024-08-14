{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.x-banananetwork.improvedDefaults;
in
{


  config = lib.mkIf cfg.enable (
    let
      prgs = config.programs;
      servDM = config.services.desktopManager;
      xDM = config.services.xserver.desktopManager;
      waylandEnabled = builtins.any (x: x) ([
        prgs.hyprland.enable
        prgs.miriway.enable
        prgs.river.enable
        prgs.sway.enable
        prgs.wayfire.enable
        (xDM.mate.enable && xDM.mate.enableWaylandSession)
        servDM.lomiri.enable # unsure wheather this is using Wayland
        servDM.plasma6.enable
      ]);
    in
    {

      # make Steam Input events on Wayland possible
      programs.steam.extest.enable = lib.mkIf (config.programs.steam.enable && waylandEnabled) true;

    }
  );


}
