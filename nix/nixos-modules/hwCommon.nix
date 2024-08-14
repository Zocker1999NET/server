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
          Configures the CPU type to expect this configuration to run on
        '';
        type = lib.types.enum [ "amd" "intel" ];
        # required
      };

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

        (
          lib.mkIf
            (cpu.type == "amd")
            { amd.updateMicrocode = true; }
        )

        (
          lib.mkIf
            (cpu.type == "intel")
            { intel.updateMicrocode = true; }
        )

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
