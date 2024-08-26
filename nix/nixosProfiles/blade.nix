# applicable to all systems running on bare hardware

{
  config,
  lib,
  pkgs,
  ...
}:
{

  imports = [
    # from here
    ./common.nix
  ];

  config = {

    # EFI by default
    boot.loader = {
      efi.canTouchEfiVariables = lib.mkDefault true;
      grub.memtest86.enable = lib.mkDefault true;
      systemd-boot = {
        enable = lib.mkDefault true;
        editor = lib.mkDefault true;
        memtest86.enable = lib.mkDefault true;
      };
    };

    environment.systemPackages = with pkgs; [
      pciutils
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
