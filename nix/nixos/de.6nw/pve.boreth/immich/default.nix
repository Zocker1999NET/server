{ lib, outputs, ... }@flakeArg:
let
  inherit (lib.lists) singleton;
in
{
  modules = [

    # testing automated system upgrades
    (
      { config, ... }:
      {
        system.autoUpgrade = {
          enable = true;
          allowReboot = true;
          flags = [
            "--print-build-logs"
            "--max-jobs"
            "0"
          ];
          # ===SYNC:general/meta/repo/url===
          flake = "github:Zocker1999NET/server#${config.networking.fqdnOrHostName}";
          operation = "switch";
          upgrade = false; # honor flake.lock
        };
      }
    )

    # config
    (
      { config, pkgs, ... }:
      {
        networking = {
          hostName = "immich";
          domain = "boreth.pve.6nw.de";
        };
        services.immich = {
          enable = true;
          host = ""; # on all interfaces
          openFirewall = true;
          port = 3001;
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
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA6DMOnOPPGFpxpa9LfoLu5cmZMybX5xRTtKLSSzpVXo root@immich.boreth.pve.6nw.de 2024-10-10";
    }

  ];
  system = "x86_64-linux";
}
