{ lib, outputs, ... }:
let
  inherit (lib.lists) singleton;
in
{
  modules = [

    # system config
    {
      # TODO cage with chromium (or other, more suitable module) for Grocy
    }

    # host config
    {
      networking.domain = "pc.6nw.de";
      networking.hostName = "nyxlite";
    }

    # hardware (Microsoft Surface 3)
    outputs.nixosProfiles.blade
    {
      # to find boot drive
      boot.initrd.availableKernelModules = [
        "mmc_block"
        "sdhci-acpi"
      ];
      # TODO (maybe) custom linux-surface kernel patches
      hardware = {
        cpu.type = "intel";
        graphics.intel.enable = true;
      };
      x-banananetwork.frontend.convertable = true;
    }

    # state
    {
      system.stateVersion = "24.05";
      x-banananetwork.vmDisko = {
        # TODO re-install with some swap
        generation = "ext4-1";
        mainDiskName = "main";
      };
    }

  ];
  system = "x86_64-linux";
}
