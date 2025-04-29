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

  backports = importOverlay ./backports.nix;

  customisations = importOverlay ./customisations.nix;

  fromFlake = importOverlay ./fromFlake.nix;

  systemd-radv-fadeout = importOverlay ./systemd-radv-fadeout;

}
