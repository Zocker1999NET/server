# applicable to all hosts running on bare hardware

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.x-banananetwork.hwCommon;
  cpu = config.hardware.cpu;
in
{

  options = {

    hardware.cpu = {

      type = lib.mkOption {
        description = ''
          Configures the CPU type to expect this configuration to run on.

          This setting is required when using generalizing options
          like option{hardware.cpu.updateMicrocode}.
        '';
        type =
          with lib.types;
          nullOr (enum [
            "amd"
            "intel"
          ]);
        # required
      };

      updateMicrocode = lib.mkEnableOption ''
        microcode updates for CPU type selected in option{hardware.cpu.type}.

        Because this module is not yet part of upstream,
        it requires option{x-banananetwork.hwCommon.enable} to be enabled.
      '';

    };

    x-banananetwork.hwCommon = {

      enable = lib.mkEnableOption ''
        settings common to all bare hardware-based hosts
      '';

    };

  };

  config = lib.mkIf cfg.enable {

    assertions = [
      {
        assertion = cfg.enable -> !config.x-banananetwork.vmCommon.enable;
        message = "hwCommon & vmCommon profiles cannot both be enabled at the same time";
      }
    ];

    boot = {

      # TODO adapt better
      loader = {
        efi.canTouchEfiVariables = lib.mkDefault true;
        systemd-boot = {
          enable = true;
          editor = lib.mkDefault true; # TODO lockdown (disable this OR enable TPM PCR checks)
          memtest86.enable = lib.mkDefault true;
        };
      };

    };

    environment.systemPackages = with pkgs; [
      pciutils
      usbutils
    ];

    hardware = {

      cpu = lib.mkMerge [

        # TODO maybe upstream?
        (
          let
            type = config.hardware.cpu.type;
            opts = isType: { updateMicrocode = lib.mkDefault (isType && config.hardware.cpu.updateMicrocode); };
          in
          {
            amd = opts (type == "amd");
            intel = opts (type == "intel");
          }
        )

        { updateMicrocode = lib.mkDefault true; }

      ];

      enableRedistributableFirmware = lib.mkDefault true;

    };

    powerManagement = {
      cpuFreqGovernor = "ondemand";
      enable = true;
    };

    services = {

      fwupd = {
        enable = true;
      };

      power-profiles-daemon = {
        # 2024-08-14: tlp seems way better in my experience, hence disable it
        enable = lib.mkIf config.services.tlp.enable false;
      };

      smartd = {
        enable = true;
      };

      tlp = {
        # energy-saving daemon, similar to powertop --autotune, but adaptive to BAT / AC
        enable = true;
      };

    };

    x-banananetwork = {

      allCommon.enable = true;
      useable.enable = lib.mkDefault true; # add docs & tools for emergencies

    };

  };

}
