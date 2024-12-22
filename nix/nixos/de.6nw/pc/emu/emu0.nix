{ lib, outputs, ... }@flakeArg:
let
  inherit (lib.lists) singleton;
in
{
  modules = [
    { systemd.network.links."10-ethernet".matchConfig.PermanentMACAddress = "00:22:4d:80:87:d2"; }
    { nixpkgs.overlays = singleton outputs.overlays.libretro-dolphin-bba; }
    ./common.nix
    # host config
    {
      networking.hostName = "emu0";
      networking.domain = "pc.6nw.de";
    }
    # hardware
    outputs.nixosProfiles.blade
    {
      hardware = {
        cpu.type = "intel";
        graphics.nvidia.enable = true;
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
