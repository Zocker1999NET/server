{ config
, lib
, pkgs
, ...
}:
let
  cfg = config.x-banananetwork.improvedDefaults;
  fx = config.programs.firefox;
in
{

  config = lib.mkIf (cfg.enable && fx.enable) {


    # TODO only on touchscreen / wayland
    environment.sessionVariables = {
      MOZ_USE_XINPUT2 = "1";
    };


    programs.firefox = {

      preferences = {
        "widget.use-xdg-desktop-portal.file-picker" = lib.mkIf config.xdg.portal.enable true;
      };

      wrapperConfig = {
        pipewireSupport = lib.mkIf config.services.pipewire.enable true;
      };

    };


  };

}
