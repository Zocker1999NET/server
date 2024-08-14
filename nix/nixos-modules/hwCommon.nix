# applicable to all hosts running on bare hardware

{ config
, lib
, pkgs
, ...
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
        type = with lib.types; nullOr enum [
          "amd"
          "intel"
        ];
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


    hardware = {

      cpu = lib.mkMerge [

        # TODO maybe upstream?
        (
          let
            type = config.hardware.cpu.type;
            opts = isType: {
              updateMicrocode = lib.mkDefault (isType && config.hardware.cpu.updateMicrocode);
            };
          in
          {
            amd = opts (type == "amd");
            intel = opts (type == "intel");
          }
        )

        {
          updateMicrocode = lib.mkDefault true;
        }

      ];

      enableRedistributableFirmware = true;

    };


    powerManagement = {
      cpuFreqGovernor = "ondemand";
      enable = true;
      powertop.enable = true;
      scsiLinkPolicy = "med_power_with_dipm";
    };


    services = {

      fwupd = {
        enable = true;
      };

      smartd = {
        enable = true;
      };

    };


    x-banananetwork = {

      allCommon.enable = true;
      vmCommon.enable = false;
      usuable.enable = lib.mkDefault true; # add docs & tools for emergencies

    };


  };


}
