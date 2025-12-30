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
      x-banananetwork = {
        serverCommon.enable = true;
        useable.enable = true;
        zfsServer = {
          enable = true;
          warnOnDefaultTimings = true;
        };
      };
    }

    # Secure Boot
    # (see https://nix-community.github.io/lanzaboote/getting-started/enable-secure-boot.html)
    {
      boot = {
        initrd.systemd.enable = true; # required for TPM unlock of LUKS drive
        loader.systemd-boot.enable = mkForce false;
        lanzaboote = {
          enable = true;
          pkiBundle = "/var/lib/sbctl";
          # automatic provisioning
          # (see https://nix-community.github.io/lanzaboote/explanation/automatic-provisioning.html)
          autoEnrollKeys = {
            enable = true;
            autoReboot = true;
          };
          autoGenerateKeys.enable = true;
        };
      };
    }
    # LUKS sealed against: with reasonings:
    # --tpm2-pcrs=0+2+3+7+8+10+12+14+15:sha1=0000000000000000000000000000000000000000
    # (hw only supports sha1)
    # 0: for UEFI firmware upgrades/downgrades
    # (1: changes on every boot, for unknown reason)
    # 2: for executed option ROM changes
    # 3: for HW changes, stayed same with USB HID, USB drive, display changes
    # (4: changes between generations because of initrd)
    # (5: includes loader.cfg from systemd-boot, changes on new generation introduction)
    # (6: unused)
    # 7: secure boot state
    # 8: GRUB unused on this system
    # (9: changes between generations because of initrd)
    # 10: Linux IMA unused on this system
    # (11: changes between generations because of initrd)
    # 12: protect against externally inserted kernel / systemd arguments
    # (13: unused, potentially changes between generations)
    # 14: shim, unused on this system
    # 15: sealed against sha1:0x0 -> light PCR 15 validation by only allowing TPM to unlock first drive (when combined with tpm2-measure-pcr)
    # (read about PCRs: https://uapi-group.org/specifications/specs/linux_tpm_pcr_registry/)

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
      # main disk is a SSD
      disko.devices.disk.main.content.partitions.luks.content.settings = {
        allowDiscards = true; # reveal empty blocks for SSD lifetime & performance
        bypassWorkqueues = true; # optimize performance
      };
      hardware = {
        cpu.type = "intel";
        graphics.intel.enable = true;
      };
    }

    # installation state
    {
      networking.hostId = "f567a250";
      system.stateVersion = "25.11";
      x-banananetwork.vmDisko = {
        generation = "luks-lvm-1";
        mainDiskName = "main";
      };
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGhhac4DO755dq6Z1SbvhpJd64i19xZ7Ndwvi8pNx9c9 root@dvorak.srv.6nw.de 2025-12-30";
    }

  ];
  system = "x86_64-linux";
}
