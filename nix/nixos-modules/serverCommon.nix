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
    # - everything everywhere in UTC
    {

      # nix-builder.boreth.pve.6nw.de : srv-autoPush at "*-*-* 23:00"

      # boreth.pve.6nw.de : VM backups at "01:00"
      # - may take up to 1 hour, when VMs were recently restarted
      # - requires router & nixnas VMs for reaching PBS & storing data

      system.autoUpgrade = {
        rebootWindow.lower = "02:00";
        dates = "02:00";
        randomizedDelaySec = "45min";
        fixedRandomDelay = true; # each unique system uses the same delay
        rebootWindow.upper = "02:55";
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

      # nix-builder.boreth.pve.6nw.de : srv-autoUpdate at "Sam *-*-* 08:00"

      # boreth.pve.6nw.de : VM backups at "13:00"

    }

    # remove legacy file from deving on productive machines
    {
      system.activationScripts.rm-issue-sshPublicHostKey = {
        supportsDryActivation = false;
        text = ''
          if [[ -e /etc/issue.d/sshPublicHostKey.issue ]]; then
            rm -v /etc/issue.d/sshPublicHostKey.issue
          fi
        '';
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

      system.autoUpgrade = {
        enable = true;
        allowReboot = true;
        flags = [
          "--print-build-logs"
          # prevent building anything local, substitute everything, otherwise abort
          "--max-jobs"
          "0"
          "--option"
          "always-allow-substitutes"
          "true"
        ];
        # ===SYNC:general/meta/repo/url===
        flake = "github:Zocker1999NET/server#${config.networking.fqdnOrHostName}";
        operation = "switch";
        upgrade = false; # honor flake.lock
      };

    }

    # security hardening
    # - ordered alphabetically
    {

      security = {

        apparmor.enable = true;

        # after boot loading not required on servers & VMs
        # - may affect plug-n-play of USB devices which are not simple HIDs
        lockKernelModules = true;

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

        dynamicIssue.modules = {
          sshHostKey.enable = true;
        };

        getty = {
          helpLine = "IPs:  \\4  \\6";
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

      services = {
        logind.settings.Login = {
          # do not suspend on closing lid (if existing)
          HandleLidSwitch = "ignore";
          HandleLidSwitchExternalPower = "ignore";
          HandleLidSwitchDocked = "ignore";
        };
      };

    }

  ]);

}
