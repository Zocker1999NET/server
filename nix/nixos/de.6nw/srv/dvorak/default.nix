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
        services = {
          # TODO (feature) integrate into Syncthing (SSD as target)
          tailscale = {
            enable = true;
            #authKeyFile = config.secrix.services.tailscale.secrets.authKey.decrypted.path;
            openFirewall = true;
            setFlags = {
              advertise-exit-node = true;
              advertise-tags = [
                "none"
                "mesh-syncthing" # TODO
              ];
            };
          };
        };
      }
    )
    {
      services.zfs = {
        autoScrub = {
          interval = "Sun *-*-01..07 13:30";
          randomizedDelaySec = "1min"; # for near to no effect
        };
        trim = {
          interval = "Sun *-*-* 09:30";
          randomizedDelaySec = "1min"; # for near to no effect
        };
      };
      x-banananetwork = {
        useable.enable = true;
        zfsServer = {
          enable = true;
          warnOnDefaultTimings = true;
        };
      };
    }

    # host config
    {
      networking = {
        hostName = "dvorak";
        domain = "srv.6nw.de";
      };
    }

    # hardware
    outputs.nixosProfiles.blade
    {
      hardware = {
        cpu.type = "intel";
        graphics.intel.enable = true;
      };
    }

    # installation state
    {
      networking.hostId = "f567a250";
      system.stateVersion = "25.05";
      x-banananetwork.vmDisko = {
        generation = "ext4-swap-1";
        mainDiskName = "main";
      };
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICT2gW4pQm/FS23zHW7TmnCJ8vjUpsCnwk4ilv50FzUS root@dvorak.srv.6nw.de 2025-04-13";
    }

  ];
  system = "x86_64-linux";
}
