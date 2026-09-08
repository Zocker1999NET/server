# Raspberry Pi 5 - 4 GB
# purpose: Kodi Media Center (LibreELEC-like appliance)
{
  inputs,
  self,
  ...
}:
{
  modules = [

    # Kodi Media Center
    {
      services.kodi = {
        enable = true;
        openFirewall = true; # web interface & event server
      };
    }

    # hardware (Raspberry Pi 5)
    self.outputs.nixosProfiles.bladeAll
    # see https://github.com/NixOS/nixos-hardware/blob/62173785b9a18c78b4a15aca2623d02bceb9d077/raspberry-pi/README.md
    inputs.nixos-hardware.nixosModules.raspberry-pi-5
    {
      # options from https://github.com/NixOS/nixos-hardware/blob/62173785b9a18c78b4a15aca2623d02bceb9d077/raspberry-pi/common/firmware.nix
      hardware.raspberry-pi.firmware = {
        enable = true; # repopulate firmaware partition on each switch
        uboot.enable = true; # enables NixOS generation boot menu
        # WARNING: generation selection might not work because USB does not come up before Linux is booted (see README)
      };
      # mesa/EGL/VA-API for hardware-accelerated video decoding & rendering
      hardware.graphics.enable = true;
    }

    # host config
    {
      networking = {
        domain = "pc.6nw.de";
        hostName = "kokoro";
      };
      x-banananetwork.serverCommon.enable = true;
    }

    # state
    {
      # standard NixOS aarch64 SD image layout
      fileSystems."/" = {
        device = "/dev/disk/by-label/NIXOS_SD";
        fsType = "ext4";
      };
      fileSystems."/boot/firmware" = {
        device = "/dev/disk/by-label/FIRMWARE";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };
      system.stateVersion = "26.05";
      # TODO set after first boot:
      # x-banananetwork.sshHostPublicKey = "ssh-ed25519 ...";
    }
  ];
  system = "aarch64-linux";
}
