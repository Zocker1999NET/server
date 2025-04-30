{
  inputs,
  lib,
  flake,
  outputs,
  self,
  ...
}@flakeArg:
let
  nixpkgs = inputs.nixpkgs;
  nixosSystem =
    { modules, system }:
    let
      modsExtended = [
        {
          system.configurationRevision = toString (
            flake.shortRev or flake.dirtyShortRev or flake.lastModified or "unknown"
          );
        }
        outputs.nixosModules.myOptions
        outputs.nixosModules.withDepends
        { home-manager.sharedModules = [ outputs.homeManagerModules.default ]; }
      ] ++ modules;
      systemArgs = {
        modules = modsExtended;
        # be aware: specialArgs will break in my nixos integration tests
        inherit system;
      };
    in
    nixpkgs.lib.nixosSystem systemArgs
    // {
      # expose module cleanly
      _banananetwork_systemArgs = systemArgs;
    };
  inherit (lib) importFlakeMod;
  importSystem = path: nixosSystem (importFlakeMod path);
in
{

  "x13yz" = nixosSystem {
    modules = [
      {
        # TODO check if required & hide into modules
        boot = {
          initrd = {
            availableKernelModules = [
              "nvme" # nvme (probably required for booting)
              "rtsx_pci_sdmmc" # probably for SD card (required for booting?)
              "xhci_pci" # for USB 3.0 (required for booting?)
            ];
            kernelModules = [
              "dm-snapshot" # pseudo-required for LVM
            ];
          };
          kernelModules = [
            "kvm-intel" # do not know if that is required here?
          ];
        };
      }
      outputs.nixosProfiles.blade
      inputs.nixos-hardware.nixosModules.lenovo-thinkpad-x13-yoga
      {
        # hardware
        hardware.cpu.type = "intel";
        hardware.graphics.intel.enable = true;
        programs.captive-browser.interface = "wlp0s20f3";
        x-banananetwork.frontend.convertable = true;
      }
      {
        # as currently installed
        boot.initrd.luks.devices."luks-herske.lvm.6nw.de" = {
          device = "/dev/disk/by-uuid/16b8f83d-0450-4c4d-9964-788575a31eec";
          preLVM = true;
          allowDiscards = true;
        };
        fileSystems."/" = {
          device = "/dev/disk/by-uuid/c93557db-e7c5-46ef-9cd8-87eb7c5753dc";
          fsType = "ext4";
          options = [ "relatime" ];
        };
        fileSystems."/boot" = {
          device = "/dev/disk/by-uuid/5F9A-9A2D";
          fsType = "vfat";
          options = [
            "uid=0"
            "gid=0"
            "fmask=0077"
            "dmask=0077"
          ];
        };
        swapDevices = [ { device = "/dev/disk/by-uuid/8482463b-ceb3-40b3-abef-b49df2de88e5"; } ];
        system.stateVersion = "24.05";
        x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG71dtqG/c0AiFBN9OxoLD35TDQm3m8LXj/BQw60PE0h root@x13yz.pc.6nw.de 2024-07-01";
      }
      {
        # host configuration
        networking.domain = "pc.6nw.de";
        networking.hostName = "x13yz";
        services.fprintd.enable = true;
        x-banananetwork.frontend.enable = true;
      }
    ];
    system = "x86_64-linux";
  };

  "nyxlite.pc.6nw.de" = importSystem ./de.6nw/pc/nyxlite;

  "emu0.pc.6nw.de" = importSystem ./de.6nw/pc/emu/emu0.nix;
  "emu1.pc.6nw.de" = importSystem ./de.6nw/pc/emu/emu1.nix;
  "emu2.pc.6nw.de" = importSystem ./de.6nw/pc/emu/emu2.nix;

  # for VM infra

  "router.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/router;

  "nixnas.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/nixnas;
  "dns.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/dns;

  "immich.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/immich;

  "ts-test.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/ts-test;

  "empty" = nixosSystem {
    # temporary, transistevy system
    modules = [
      # TODO split vmCommon & use here
      (
        { config, lib, ... }:
        {
          disko.devices.disk.main.device = lib.mkForce "/dev/sda";
          # EFI only
          boot.loader = {
            efi.canTouchEfiVariables = true;
            grub.enable = false;
            grub.efiSupport = true;
            systemd-boot.enable = true;
          };
          services = {
            getty.helpLine = "IPs:  \\4  \\6";
            openssh.enable = true;
          };
          x-banananetwork = {
            allCommon.enable = true;
            useable.enable = true;
          };
          users = {
            mutableUsers = false; # TODO move that (maybe to common?)
            users.${config.x-banananetwork.userName} = {
              description = config.x-banananetwork.userName;
              extraGroups = [ "wheel" ];
              hashedPassword = "$y$j9T$MdvgnTFGyCnZ.sLhXK7.w.$VkI6NqE7ZaN7xULmOrYCvgC6Sot19S0RWf.FmrOaLnC";
              isNormalUser = true;
              openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
            };
            users.root.openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
          };
        }
      )
      # hardware
      outputs.nixosProfiles.allHardware
      # other config
      (
        { config, lib, ... }:
        {
          networking.hostName = "empty";
          networking.domain = "temp.6nw.de";
          secrix.hostPubKey = lib.mkForce null;
        }
      )
      # "installation" state
      (
        { config, lib, ... }:
        {
          system.stateVersion = lib.versions.majorMinor config.system.nixos.version;
          x-banananetwork.vmDisko = {
            generation = config.x-banananetwork.vmDisko.recommendedGeneration;
            mainDiskName = "main";
          };
        }
      )
    ];
    system = "x86_64-linux";
  };

  # (note) build: .#nixosConfigurations.auto-iso.config.system.build.isoImage
  "auto-iso" = nixosSystem {
    modules = [
      outputs.nixosProfiles.installer
      (
        { config, pkgs, ... }:
        {
          config = {
            isoImage.edition = "de.6nw-auto";
            networking.hostName = "auto-iso";
            unattendedInstaller = {
              enable = true;
              target = self.empty;
            };
            users.users.root.openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
            # TODO for flake
            #systemd.services.unattended-installer = {
            #  path = [ pkgs.git ];
            #  preStart = ''
            #    echo waiting to ensure network fully established
            #    sleep 20
            #  '';
            #};
            #unattendedInstaller.flake = "git+https://git.banananet.work/banananetwork/server#empty-vm"; # ===SYNC:general/meta/repo/url
          };
        }
      )
    ];
    system = "x86_64-linux";
  };

  /*
    nixosInstPlasma = nixpkgs.lib.nixosSystem {
      modules = lib.singleton (
        { modulesPath, ... }:
        {
          imports = lib.singleton "${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares-plasma6.nix";
          config.isoImage.squashfsCompression = "zstd";
        }
      );
      system = "x86_64-linux";
    };

    nixosInstMinimal = nixpkgs.lib.nixosSystem {
      modules = lib.singleton (
        { modulesPath, ... }:
        {
          imports = lib.singleton "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix";
        }
      );
      system = "x86_64-linux";
    };
  */

}
