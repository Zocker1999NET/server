{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.x-banananetwork.improvedDefaults;
in
{

  imports = [
    ./command-not-found.nix
    ./firefox.nix
    ./networking.nix
    ./power-profiles-daemon.nix
    ./powertop-tlp.nix
    ./sshAuthorize.nix
    ./wayland.nix
  ];

  options = {

    x-banananetwork.improvedDefaults = {

      enable = lib.mkEnableOption ''
        improved defaults for nixpkgs NixOS modules.

        Defaults are only changed conditionally,
        e.g. modules, which are enabled by default,
        get automatically disabled
        if another incompatible module is enabled.
      '';

    };

  };

}
