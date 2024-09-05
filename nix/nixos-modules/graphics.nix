{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.graphics;
in
{

  options = {

    hardware.graphics = {

      required = lib.mkEnableOption "checks enforcing that at least one graphic driver is installed";

      amd.enable = lib.mkEnableOption "AMD graphic drivers";

      intel.enable = lib.mkEnableOption "Intel graphic drivers";

    };

  };

  config = lib.mkMerge [

    {
      assertions = [
        {
          assertion = cfg.required -> cfg.amd.enable || cfg.intel.enable;
          message = "'hardware.graphics.required' not fullfilled by any of 'hardware.graphics.*.enable'";
        }
      ];
    }

    (
      # TODO replace with drivers
      lib.mkIf cfg.amd.enable {
        assertions = lib.singleton {
          assertion = !cfg.amd.enable;
          message = "graphics module missing support for AMD drivers";
        };
      }
    )

    (lib.mkIf cfg.intel.enable {
      hardware.opengl = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-media-sdk
          libvdpau-va-gl
        ];
        extraPackages32 = with pkgs.pkgsi686Linux; [
          # limited set for Steam & co.
          intel-media-driver
        ];
      };
    })

  ];

}
