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

      nvidia = {
        enable = lib.mkEnableOption "Nvidia graphic drivers (meaning newest drivers by default)";
        open = lib.mkEnableOption "open-source kernel module in favor of (check [NixOS Wiki](https://wiki.nixos.org/wiki/Nvidia))";
      };

    };

  };

  config = lib.mkMerge [

    {
      assertions = [
        {
          assertion = cfg.required -> cfg.amd.enable || cfg.intel.enable || cfg.nvidia.enable;
          message = "'hardware.graphics.required' not fullfilled by any of 'hardware.graphics.*.enable'";
        }
      ];
    }

    # see: https://wiki.nixos.org/wiki/AMD_GPU
    (lib.mkIf cfg.amd.enable {
      hardware.graphics = {
        enable = true;
        # more seems not required
      };
    })

    # see: https://wiki.nixos.org/wiki/Intel_Graphics
    (lib.mkIf cfg.intel.enable {
      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "iHD";
      };
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          vpl-gpu-rt
        ];
        extraPackages32 = with pkgs.pkgsi686Linux; [
          # limited set for Steam & co.
          intel-media-driver
        ];
      };
      services.xserver.videoDrivers = lib.singleton "modesetting";
    })

    # see: https://wiki.nixos.org/wiki/NVIDIA
    (lib.mkIf cfg.nvidia.enable {
      hardware = {
        # TODO set priority per case
        nvidia = lib.mkDefault {
          modesetting.enable = true;
          powerManagement.enable = false;
          powerManagement.finegrained = false;
          open = cfg.nvidia.open;
          nvidiaSettings = true;
          # TODO select driver based on GPU generation
        };
        graphics = {
          enable = true;
        };
      };
      services.xserver.videoDrivers = lib.singleton "nvidia";
      x-banananetwork.autoUnfree.names = [
        "nvidia-persistenced"
        "nvidia-settings"
        "nvidia-x11"
      ];
    })

  ];

}
