{ config
, lib
, pkgs
, ...
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

    (
      lib.mkIf
        cfg.required
        {
          assertations = [ (cfg.amd.enable || cfg.intel.enable) ];
        }
    )

    (
      # TODO replace with drivers
      lib.mkIf
        cfg.amd.enable
        {
          assertions = [{
            assertion = !cfg.amd.enable;
            message = "graphics module missing support for AMD drivers";
          }];
        }
    )

    (
      lib.mkIf
        cfg.intel.enable
        {
          hardware.opengl = {
            enable = true;
            extraPackages = with pkgs; [
              intel-media-driver
              intel-media-sdk
              libvdpau-va-gl
            ];
          };
        }
    )

  ];


}
