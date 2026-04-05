{ lib, ... }@flakeArg:
let
  inherit (builtins) foldl';
  inherit (lib) systemSpecificVars;
  rawImport = path: import path flakeArg;
  # TODO upstream
  chainOverlays =
    overlays: final: prev:
    foldl' (acc: elem: acc // elem final acc) prev overlays;
  wrapOverlay =
    overlay: final: prev:
    overlay (systemSpecificVars prev.system) final prev;
  importOverlay = path: wrapOverlay (rawImport path);
in
{

  # TODO combine reasonable stuff into default

  backports = chainOverlays [
    (importOverlay ./backports.nix)
    (importOverlay ./backport-scopes-manually.nix)
  ];

  customisations = importOverlay ./customisations.nix;

  fromFlake = importOverlay ./fromFlake.nix;

  libretro-dolphin-bba = importOverlay ./libretro-dolphin-bba;

  systemd-radv-fadeout = importOverlay ./systemd-radv-fadeout;

  taskwarrior3-customs = importOverlay ./taskwarrior3-customs;

  upgrades = importOverlay ./upgrades.nix;

}
