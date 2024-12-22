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
        environment.systemPackages = with pkgs; [
          #
        ];
        networking = {
          hostName = "ts-test";
          domain = "boreth.pve.6nw.de";
        };
        services.tailscale = {
          enable = true;
          authKeyFile = config.secrix.services.tailscaled-autoconnect.secrets.authKey.decrypted.path;
          openFirewall = true;
        };
        secrix.services.tailscaled-autoconnect.secrets.authKey.encrypted.file = ./ts-auth-key;
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
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF73X6RkwXLkAKd/3TcWJMJ9cNt6wkf5wDR922+4YEAO root@router.boreth.pve.6nw.de 2024-09-06";
    }

  ];
  system = "x86_64-linux";
}
