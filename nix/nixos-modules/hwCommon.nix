# applicable to all hosts running on bare hardware

{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.x-banananetwork.hwCommon;
in
{


  options = {

    x-banananetwork.hwCommon = {

      enable = lib.mkEnableOption ''
        settings common to all bare hardware-based hosts
      '';

      cpu = lib.mkOption {
        description = ''
          Configures the CPU type to expect this configuration to run on
        '';
        type = lib.types.enum [ "amd" "intel" ];
        # required
      };

    };

  };


  config = lib.mkIf cfg.enable {


    hardware = {

      cpu = lib.mkMerge [

        (
          lib.mkIf
            (cfg.cpu == "amd")
            { amd.updateMicrocode = true; }
        )

        (
          lib.mkIf
            (cfg.cpu == "intel")
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
