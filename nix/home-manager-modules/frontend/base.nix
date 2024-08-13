# this stuff replaces all settings which would be configured by the corresponding frontend NixOS module

{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.x-banananetwork.frontend;
in
{

  config = lib.mkIf (cfg.enable && !cfg.nixosModuleCompat) {

    assertions = [
      {
        assertion = !cfg.nixosModuleCompat;
        message = "missing implementation of base stuff";
      }
    ];

  };

}
