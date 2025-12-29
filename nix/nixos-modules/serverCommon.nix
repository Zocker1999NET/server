# applicable to all my server-like systems (be them blades or VMs)

{
  config,
  lib,
  ...
}:
let
  cfg = config.x-banananetwork.serverCommon;
  inherit (lib) types;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkDefault mkIf mkMerge;
  inherit (lib.options) mkEnableOption mkOption;
in
{

  options.x-banananetwork.serverCommon = {

    enable = mkEnableOption ''
      settings for all my server-like systems
    '';

    userName = mkOption {
      description = ''
        username of administrative user.
      '';
      type = types.str;
      example = "username";
    };

    hashedPassword = mkOption {
      description = ''
        hash of password of adminstrative user.

        This can e.g. be generated using mkpasswd.
      '';
      type = with types; nullOr str;
      default = null;
    };

  };

  config = mkIf cfg.enable (mkMerge [

    # timing-related options
    # - ordered by time of operation (ignoring date)
    {

      system.autoUpgrade = {
        rebootWindow.lower = "01:00";
        dates = "01:00";
        randomizedDelaySec = "45min";
        rebootWindow.upper = "02:50";
      };

      # service specific operations
      services.nextcloud = {
        autoUpdateApps.startAt = "03:00";
        settings.maintenance_window_start = 3; # +4h
      };

      nix.gc = {
        # could take longer
        dates = "04:15";
        randomizedDelaySec = "30min";
      };

      nix.optimise = {
        # should not take long because of auto-optimise-store
        dates = singleton "05:30";
      };

      services.zfs = {
        autoScrub = {
          interval = "Sun *-*-01..07 06:30";
          randomizedDelaySec = "1min"; # has near to no effect
        };
        trim = {
          interval = "Sam *-*-* 06:30";
          randomizedDelaySec = "1min";
        };
      };

    }

    # automatic maintenance
    # - ordered alphabetically
    {

      nix = {

        gc = {
          automatic = true;
          options = mkDefault "--delete-older-than 30d";
        };

        optimise = {
          automatic = true;
        };

        settings = {
          max-free = mkDefault (3 * 1024 * 1024 * 1024);
          min-free = mkDefault (512 * 1024 * 1024);
        };
      };

    }

    # security hardening
    # - ordered alphabetically
    {

      security = {

        apparmor.enable = true;

        lockKernelModules = true; # after boot loading not required on servers & VMs

        sudo = {
          enable = true;
          execWheelOnly = mkDefault true;
          extraConfig = ''
            Defaults lecture = never
          '';
        };

      };

      services = {

        openssh = {
          authorizedKeysInHomedir = false;
          authorizedKeysOnly = true;
        };

      };

    }

    # for manual maintenance
    # - ordered alphabetically
    {

      networking = {

        firewall = {
          allowPing = mkDefault true;
        };

      };

      services = {

        getty = {
          dynamicHelpLine = {
            sshPublicHostKey.enable = true;
          };
        };

        openssh = {
          enable = true;
          openFirewall = true;
        };

      };

      users = {
        mutableUsers = false;
        users.${cfg.userName} = {
          uid = 1000;
          description = cfg.userName;
          extraGroups = [
            (mkIf config.networking.networkmanager.enable "networkmanager")
            "wheel"
          ];
          inherit (cfg) hashedPassword;
          isNormalUser = true;
          openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
        };
        users.root.openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
      };

      x-banananetwork = {
        debugMinimal.enable = true;
      };

    }

    # anything generic
    # - ordered alphabetically
    {

      x-banananetwork = {
        allCommon.enable = true;
      };

    }

  ]);

}
