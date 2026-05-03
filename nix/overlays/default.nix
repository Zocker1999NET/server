{ libBNet, ... }@flakeArg:
let
  inherit (builtins) foldl';
  inherit (libBNet) systemSpecificVars;
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
rec {

  # combines overlays that are assigned by default to every NixOS configuration
  # see nix/nixosModules/default.nix
  default = chainOverlays [
    backports
    fromFlake
    taskwarrior3-customs
    upgrades
  ];

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
