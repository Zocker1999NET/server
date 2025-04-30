{ lib, outputs, ... }@flakeArg:
let
  inherit (lib.lists) singleton;
in
{
  modules = [
    { systemd.network.links."10-ethernet".matchConfig.PermanentMACAddress = "88:d7:f6:7e:96:8f"; }
    { nixpkgs.overlays = singleton outputs.overlays.libretro-dolphin-bba; }
    ./common.nix
    # host config
    {
      networking.hostName = "emu1";
      networking.domain = "pc.6nw.de";
    }
    # hardware
    outputs.nixosProfiles.blade
    {
      hardware = {
        cpu.type = "amd";
        graphics.amd.enable = true;
      };
    }
    # state
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
