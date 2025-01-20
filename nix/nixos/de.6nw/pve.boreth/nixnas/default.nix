{ lib, outputs, ... }@flakeArg:
let
  inherit (builtins) concatStringsSep;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkForce;
in
{
  modules = [

    # config
    # TODO split from blade to hdds
    # HDDs via PCIe passthrough
    (
      { pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          lm_sensors
          pciutils
        ];
        services.smartd = {
          enable = true;
        };
      }
    )

    # mount outside stuff
    (
      { config, pkgs, ... }:
      {
        boot.supportedFilesystems.cifs = true;
        fileSystems."/mnt/wg-tv" = {
          device = "//10.11.11.160/wg-tv";
          fsType = "cifs";
          options = [
            # this line prevents hanging on network split
            "x-systemd.automount,noauto,x-systemd.idle-timeout=60,x-systemd.device-timeout=5s,x-systemd.mount-timeout=5s"
            "username=nobody,guest"
          ];
        };
        security.lockKernelModules = mkForce false; # TODO cifs crypto requires some additional modules yet unknown
      }
    )

    # share our stuff
    (
      { config, ... }:
      {
        networking.firewall.allowedTCPPorts = singleton 445; # .openFirewall opens more than I require
        services.samba = {
          enable = true;
          nmbd.enable = false;
          openFirewall = false; # opens more than I require
          winbindd.enable = false;
          settings = {
            global = {
              workgroup = "WORKGROUP";
              "server string" = config.networking.hostName;
              "netbios name" = config.networking.hostName;
              security = "user";
              "guest account" = "nobody";
              "map to guest" = "bad user"; # invalid user names -> guest account
              "valid users" = concatStringsSep " " [
                "nobody" # so list is non-empty -> effective
                "+smb"
              ];
              "server min protocol" = "SMB3";
              #"server smb encrypt" = "desired"; # even "desired" not supported by some Linux implementations
              # disable default shenanigangs because Samba is optimized for Linux-Windows sharing
              "map archive" = "no"; # https://stackoverflow.com/a/20966148
              "nt acl support" = "no";
            };
            # for internal services (VMs)
            pbs-boreth = {
              path = "/mnt/io.zfs.6nw.de/Backups/pbs.boreth.pve.6nw.de";
              browseable = "no";
              "read only" = "no";
              "guest ok" = "no";
              "valid users" = "pbs-boreth";
            };
            # for external services
            Games = {
              path = "/mnt/metis.zfs.6nw.de/Gaming/Games";
              browseable = "yes";
              "read only" = "yes";
              "guest ok" = "yes";
              "force user" = "nobody";
              "force group" = "nogroup";
            };
            /*
              # had issue:
              # - guests could only modify based on others permissions
              # - new files & dirs had unusable umask for others perms
              # - probably because of Samba applying others perms to guests (unverified)
              inbox = {
                path = "/mnt/metis.zfs.6nw.de/Gaming/Games/inbox";
                browseable = "yes";
                "read only" = "no";
                "guest ok" = "yes";
                "force user" = "nobody";
                "force group" = "nogroup";
              };
            */
          };
        };
        # to ensure permissions are set correctly
        systemd.tmpfiles.rules = [
          "e /mnt/io.zfs.6nw.de/Backups/pbs.boreth.pve.6nw.de 0700 pbs-boreth smb -"
        ];
        # user management
        users.users = {
          pbs-boreth = {
            isSystemUser = true;
            group = "smb";
            # by default, users cannot login (i.e. "nologin" shell & password locked)
            samba.passwordFile =
              config.secrix.services."samba-user-config".secrets."smb_pbs-boreth".decrypted.path;
          };
          # rewrite existing users for permission allignment
          # TODO remove when adapted globally
          zocker = {
            group = "zocker";
            extraGroups = singleton "users";
          };
        };
        users.groups.smb = { };
        users.groups.zocker.gid = config.users.users.zocker.uid;
        # secrets management
        secrix.services."samba-user-config".secrets = {
          # xkcdpass -n 8 | secr encrypt nixnas.boreth.pve.6nw.de nix/nixos/de.6nw/pve.boreth/nixnas/smb_pbs-boreth.age
          "smb_pbs-boreth".encrypted.file = ./smb_pbs-boreth.age;
        };
      }
    )

    # pool management
    {
      boot.zfs = {
        extraPools = [
          "io.zfs.6nw.de"
          "metis.zfs.6nw.de"
        ];
        # for automount, keys are stored on in plain text on VM partition (secured by PVE full disk encryption)
        # location: /root/zfs-keys/<POOL-NAME>
        # TODO migrate keys to nix config (via secrix)
        # TODO (maybe) migrate that to clevis magic
        requestEncryptionCredentials = [
          "io.zfs.6nw.de"
          "metis.zfs.6nw.de"
        ];
      };
    }

    {
      x-banananetwork = {
        useable.enable = true;
        vmCommon.enable = true;
        zfsServer = {
          enable = true;
          optimizeArcMemory = true;
          # timing globally defined in vmCommon (ensure that)
          warnOnDefaultTimings = true;
        };
        # TODO autoSnapshots from vital stuff
        # TODO autoBackups to remote location
      };
    }

    # host config
    {
      networking = {
        hostName = "nixnas";
        domain = "boreth.pve.6nw.de";
      };
    }

    # hardware
    outputs.nixosProfiles.pveGuest
    {
      # required to make my HBA working (with PCIe passthrough)
      # Broadcom / LSI SAS2308 PCI-Express Fusion-MPT SAS-2 [1000:0087] (rev 05)
      # Subsystem: Broadcom / LSI 9207-8i SAS2.1 HBA [1000:3020]
      boot.kernelParams = [ "iommu=pt" ];
      hardware.memory.availableBytes = 16 * 1024 * 1024 * 1024;
    }

    # installation state
    {
      networking.hostId = "b75680fd";
      system.stateVersion = "24.05";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ7GcZn60E3QwntZ4JNzEXW/pJIRzI2HxCEvKpvMnHLT root@nixnas.boreth.pve.6nw.de 2024-09-25";
    }

  ];
  system = "x86_64-linux";
}
