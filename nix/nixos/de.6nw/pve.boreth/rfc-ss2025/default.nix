{ lib, outputs, ... }@flakeArg:
let
  inherit (lib.lists) singleton;
in
{
  modules = [

    # config
    (
      { config, pkgs, ... }:
      {
        networking = {
          hostName = "rfc-ss2025";
          domain = "boreth.pve.6nw.de";
        };
        x-banananetwork = {
          useable.enable = true;
          vmCommon.enable = true;
        };
      }
    )

    # hardware
    outputs.nixosProfiles.pveGuest

    # installation state
    {
      system.stateVersion = "24.11";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
    }

  ];
  system = "x86_64-linux";
}
