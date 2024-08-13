{ config
, lib
, pkgs
, ...

}: {


  imports = [
    ./base.nix
    ./extension.nix
  ];


  options = {

    x-banananetwork.frontend = {

      enable = lib.mkEnableOption ''
        settings for frontend configuration in Home-Manager
      '';

      nixosModuleCompat = lib.mkEnableOption ''
        compatibility to the corresponding frontend NixOS configuration.

        This is created by opting out to configure stuff
        which is already configured by the corresponding NixOS module.
      '';

    };

  };


}
