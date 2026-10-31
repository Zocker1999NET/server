# Silverstone old stuff
# purpose: Kodi Media Center (LibreELEC-like appliance)
# Hardware:
# - CPU: Intel Core i5-4590S (Haswell)
# - Memory: 8 GB DDR3
# - Storage: 64 GB SSD
# - Graphics: Intel HD Graphics 4600 (integrated)
{
  inputs,
  lib,
  self,
  ...
}:
let
  inherit (lib.meta) getExe;
  nixosHW = inputs.nixos-hardware;
  cageUser = "cage";
  webservice = "https://www.crunchyroll.com/discover";
in
{
  modules = [

    # TODO make selectable on runtime (Kodi vs. Cage)
    # Kodi Media Center
    # ({ config, ... }: {
    #   services.kodi = {
    #     enable = true;
    #     openFirewall = true; # web interface & event server
    #     addons = with config.services.kodi.package.packages; [
    #       invidious
    #       mediacccde
    #       sendtokodi
    #       sponsorblock
    #     ];
    #   };
    # })
    ({ pkgs, ... }: {
      services.cage = {
        enable = true;
        user = cageUser;
        program = "${getExe pkgs.firefox} --kiosk ${webservice}";
      };
    })

    # hardware
    self.outputs.nixosProfiles.blade
    "${nixosHW}/common/cpu/intel/haswell"
    "${nixosHW}/common/pc/ssd"

    # host config
    {
      networking = {
        domain = "pc.6nw.de";
        hostName = "silverstone";
      };
      x-banananetwork.serverCommon.enable = true;
    }

    # state
    {
      system.stateVersion = "26.05";
      x-banananetwork.vmDisko = {
        generation = "ext4-1";
        mainDiskName = "main";
      };
      x-banananetwork.sshHostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM7LKu14jQiBFwiFM1rfRdXYW3YG5qCtytmDoSA579D0 root@silverstone.pc.6nw.de 2026-10-31";
    }
  ];
  system = "x86_64-linux";
}
