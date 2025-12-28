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
      ]
      ++ modules;
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

  "x13yz" = importSystem ./de.6nw/pc/x13yz;

  "nyxlite.pc.6nw.de" = importSystem ./de.6nw/pc/nyxlite;

  "emu0.pc.6nw.de" = importSystem ./de.6nw/pc/emu/emu0.nix;
  "emu1.pc.6nw.de" = importSystem ./de.6nw/pc/emu/emu1.nix;
  "emu2.pc.6nw.de" = importSystem ./de.6nw/pc/emu/emu2.nix;

  # for VM infra

  "router.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/router;

  "nixnas.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/nixnas;
  "dns.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/dns;

  "immich.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/immich;

  "nix-builder.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/nix-builder;

  "ts-test.boreth.pve.6nw.de" = importSystem ./de.6nw/pve.boreth/ts-test;

  "empty" = importSystem ./de.6nw/temp/empty;

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

  # TODO integrate into auto-iso, see taskwarrior:///321e5090-fe7d-4fc8-aeee-0117a344f33a
  # (note) build: .#nixosConfigurations.mgmt-iso.config.system.build.isoImage
  "mgmt-iso" = nixosSystem {
    modules = [
      outputs.nixosProfiles.installer
      (
        { config, pkgs, ... }:
        {
          config = {
            documentation.info.enable = lib.mkForce false;
            environment.systemPackages = with pkgs; [
              nwipe # make wiping disks easier
            ];
            isoImage.edition = "de.6nw-mgmt";
            networking.hostName = "mgmt-iso";
            programs.disko-install-menu = {
              enable = true;
              listedFlakes.defaultFlake = {
                offlineHosts = {
                  "empty" = true;
                };
                offlineReference = flake;
              };
              offlineCapable = true;
              options = {
                # TODO autostart
                defaultFlake = "github:Zocker1999NET/server"; # ===SYNC:general/meta/repo/url
                defaultHost = "empty";
              };
            };
            users.users.root.openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
            x-banananetwork = {
              allCommon.enable = true;
              useable.enable = true;
            };
          };
        }
      )
      ./../offlineInstallDeps.nix
    ];
    system = "x86_64-linux";
  };

  "iehsrv995" = nixosSystem {
    # TODO copy config from host
    modules = [
      # TODO move into own modules
      (
        { config, ... }:
        {
          services.btrfs.autoScrub = {
            enable = true;
            interval = "weekly";
          };
          nix.sshServe = {
            enable = true;
            keys = config.x-banananetwork.sshPublicKeys;
            protocol = "ssh";
            write = true;
          };
          nix.settings.trusted-users = [ "nix-ssh" ];
          # allow connection for remote building
          users.users.iehadmin.openssh.authorizedKeys.keys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKko0tcHOmCxi/ilFbVJ9N+U+34B9r6RFdmGfrBaob6C root@x13yz.pc.6nw.de"
          ];
        }
      )
      # host config
      {
        networking.domain = "ieh.kit.edu";
        networking.hostName = "iehsrv995";
        x-banananetwork.useable.enable = true;
        x-banananetwork.userName = "iehadmin";
        x-banananetwork.vmCommon.enable = true;
      }
      # hardware
      outputs.nixosProfiles.pveGuest
      # installation state
      (
        let
          btrfsRootOpts = [ "compress=zstd" ];
        in
        {
          fileSystems."/" = {
            device = "/dev/disk/by-uuid/cc109c2d-c70a-481d-9f1a-4c5c2e9cc964";
            fsType = "btrfs";
            options = [ "subvol=root" ] ++ btrfsRootOpts;
          };
          fileSystems."/home" = {
            device = "/dev/disk/by-uuid/cc109c2d-c70a-481d-9f1a-4c5c2e9cc964";
            fsType = "btrfs";
            options = [ "subvol=home" ] ++ btrfsRootOpts;
          };
          fileSystems."/nix" = {
            device = "/dev/disk/by-uuid/cc109c2d-c70a-481d-9f1a-4c5c2e9cc964";
            fsType = "btrfs";
            options = [ "subvol=nix" ] ++ btrfsRootOpts;
          };
          fileSystems."/boot" = {
            device = "/dev/disk/by-uuid/C551-A77E";
            fsType = "vfat";
            options = [
              "fmask=0077"
              "dmask=0077"
            ];
          };
          swapDevices = [ { device = "/dev/disk/by-uuid/42ac2839-0bb1-45ac-ad00-6b49142bf965"; } ];
        }
      )
      {
        system.stateVersion = "24.05";
        x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJlrzgVqPcIUbkMHVOQZgee9j2CwfDiW4oJhUKdIcQKV iehsrv995";
      }
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
