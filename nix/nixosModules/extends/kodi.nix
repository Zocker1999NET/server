# Kodi Media Center as a LibreELEC-like appliance
# - runs directly on the GPU (GBM), no X11, supports HDR
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.options)
    literalExpression
    mkEnableOption
    mkOption
    mkPackageOption
    ;
  inherit (lib.strings) escapeShellArg;
  cfg = config.services.kodi;
in
{

  _class = "nixos";

  options.services.kodi = {

    enable = mkEnableOption ''
      Kodi Media Center as a LibreELEC-like appliance.

      Runs directly on the GPU (GBM, no X11), the only variant able to display HDR content.
    '';

    openFirewall = mkEnableOption ''
      opening the ports required by Kodi's network services in the firewall.
    '';

    package = mkPackageOption pkgs "kodi-gbm" {
      extraDescription = ''
        Should be a GBM variant of Kodi,
        i.e. one that runs directly on the GPU.
      '';
    };

    username = mkOption {
      description = ''
        The user to run Kodi as.
      '';
      type = types.str;
      default = "kodi";
      example = "kodi";
    };

    autoLogin = mkOption {
      description = ''
        Whether to auto-login the {option}`services.kodi.username` user on tty1
        and launch Kodi directly (LibreELEC-style appliance).
      '';
      type = types.bool;
      default = true;
      example = false;
    };

    addons = mkOption {
      description = ''
        Kodi add-ons to install, passed through {option}`services.kodi.package`'s `withPackages`.
      '';
      type = with types; listOf package;
      default = [ ];
      example = literalExpression ''
        with pkgs.kodi-gbm.packages; [
          jellyfin
          pvr-iptvsimple
        ]
      '';
    };

    # the final Kodi package, including add-ons
    finalPackage = mkOption {
      description = ''
        The final Kodi package, i.e. {option}`services.kodi.package` with {option}`services.kodi.addons` applied.
      '';
      type = types.package;
      readOnly = true;
      internal = true;
    };

  };

  config = mkIf cfg.enable (mkMerge [

    # the Kodi package itself
    {
      services.kodi.finalPackage = cfg.package.withPackages (p: cfg.addons);
      environment.systemPackages = [ cfg.finalPackage ];

      # audio: use ALSA directly, which supports HDMI audio passthrough
      hardware.alsa.enable = true;
      services.pulseaudio.enable = false;
      services.pipewire.enable = false;

      # the user to run Kodi as
      users.users.${cfg.username} = {
        description = "Kodi Media Center User";
        extraGroups = [
          "input" # allow kodi access to keyboards
          "video" # DRM/GBM access
          "audio" # ALSA access
        ];
        isNormalUser = true;
      };
    }

    # auto-login & launch kodi on tty1 (LibreELEC-style appliance)
    (mkIf cfg.autoLogin {
      services.getty.autologinUser = cfg.username;
      environment.loginShellInit = ''
        if [ "$(tty)" = "/dev/tty1" ] && [ "$USER" = ${escapeShellArg cfg.username} ]; then
          exec ${cfg.finalPackage}/bin/kodi-standalone
        fi
      '';
    })

    # Kodi network services
    (mkIf cfg.openFirewall {
      networking.firewall = {
        allowedTCPPorts = [
          8080 # Kodi web interface
        ];
        allowedUDPPorts = [
          9777 # Kodi event server (kodi-send)
        ];
      };
    })

  ]);

}
