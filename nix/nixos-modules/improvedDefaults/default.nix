{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.x-banananetwork.improvedDefaults;
in
{


  imports = [
    ./command-not-found.nix
    ./powertop-tlp.nix
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
