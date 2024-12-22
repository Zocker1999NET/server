{ lib, outputs, ... }@flakeArg:
let
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce;
in
{
  modules = [

    # config
    (
      { config, pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          #
        ];
        networking = {
          hostName = "proxy";
          domain = "boreth.pve.6nw.de";
        };
        services.caddy = {
          enable = true;
          virtualHosts = {
            # TODO domain
            # TODO lets encrypt
            "test-cloud.banananet.work".extraConfig = ''
              reverse_proxy 10.32.1.121
              tls internal
            '';
          };
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
      system.stateVersion = "24.05";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
    }

  ];
  system = "x86_64-linux";
}
