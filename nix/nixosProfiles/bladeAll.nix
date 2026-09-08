# applicable to all systems running on bare hardware
# (for any hardware, like Raspberry Pi)

{
  config,
  lib,
  pkgs,
  ...
}:
{

  _class = "nixos";

  imports = [
    # from here
    ./common.nix
  ];

  config = {

    environment.systemPackages = with pkgs; [
      lm_sensors
      pciutils
      smartmontools
      usbutils
    ];

    hardware = {
      cpu.updateMicrocode = lib.mkIf config.hardware.enableRedistributableFirmware true;
      enableRedistributableFirmware = lib.mkDefault true;
    };

    powerManagement = {
      cpuFreqGovernor = "ondemand";
      enable = lib.mkDefault true;
    };

    services = {

      fwupd = {
        enable = true;
      };

      smartd = {
        enable = true;
        # TODO smartd configure fallback notifications (servers are/should be configured somewhere else)
      };

      tlp = {
        # 2024-08-14: tlp seems way better in my experience
        # energy-saving daemon, similar to powertop --autotune, but adaptive to BAT / AC
        enable = true;
      };

    };

    x-banananetwork = {
      # add docs & tools for emergencies
      useable.enable = lib.mkDefault true;
    };

  };
}
