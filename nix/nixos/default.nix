{
  inputs,
  lib,
  flake,
  outputs,
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

}
