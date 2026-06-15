{
  importWithFlake,
  withSystem,
  ...
}@flakeArg:
let
  inherit (builtins) foldl';
  # TODO upstream
  # https://github.com/NixOS/nixpkgs/issues/516604
  chainOverlays =
    overlays: final: prev:
    foldl' (acc: elem: acc // elem final acc) prev overlays;
  wrapOverlay =
    overlay: final: prev:
    (withSystem prev.stdenv.hostPlatform.system overlay) final prev;
  importOverlay = path: wrapOverlay (importWithFlake path);
in
{
  _class = "flake";
  flake.overlays = rec {

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

    systemd-radv-fadeout = importOverlay ./systemd-radv-fadeout;

    taskwarrior3-customs = importOverlay ./taskwarrior3-customs;

    upgrades = importOverlay ./upgrades.nix;

  };
}
