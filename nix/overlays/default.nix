{ lib, ... }@flakeArg:
let
  inherit (lib) systemSpecificVars;
  rawImport = path: import path flakeArg;
  wrapOverlay =
    overlay: final: prev:
    overlay (systemSpecificVars prev.system) final prev;
  importOverlay = path: wrapOverlay (rawImport path);
in
{

  # TODO combine reasonable stuff into default

  backports = importOverlay ./backports.nix;

  customisations = importOverlay ./customisations.nix;

  fromFlake = importOverlay ./fromFlake.nix;

  libretro-dolphin-bba = importOverlay ./libretro-dolphin-bba;

  systemd-radv-fadeout = importOverlay ./systemd-radv-fadeout;

  xmm7360 = importOverlay ./xmm7360;

  upgrades = importOverlay ./upgrades.nix;

}
