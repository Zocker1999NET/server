# applicable to all service VMs running on a hypervisor (currently Proxmox/QEMU assumed)

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.x-banananetwork.vmCommon;
  inherit (builtins) genList;
  inherit (lib.trivial) flip;
in
{

  options = {

    x-banananetwork.vmCommon = {

      enable = lib.mkEnableOption ''
        settings for all my VMs
      '';

      userName = lib.mkOption {
        description = ''
          username of administrative user.
        '';
        type = lib.types.str;
        example = "username";
      };

      hashedPassword = lib.mkOption {
        description = ''
          hash of password of adminstrative user.

          This can e.g. be generated using mkpasswd.
        '';
        type = with lib.types; nullOr str;
        default = null;
      };

    };

  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [

      {

        # timing-related options
        # - ordered by chronological order

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
          dates = lib.singleton "05:30";
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

      {

        # all other options

        boot = {

          loader = {
            efi.canTouchEfiVariables = true;
            grub.enable = false;
            systemd-boot = {
              enable = true;
              configurationLimit = 16;
              editor = true; # access to VM console/KVM should be locked
            };
          };

        };

        # TODO device if magic is enough
        #disko.devices.disk.main.device = "/dev/sda";

        networking = {

          firewall = {
            allowPing = lib.mkDefault true;
            logRefusedConnections = lib.mkDefault false;
            # TODO
          };

          useDHCP = lib.mkDefault true;
          useNetworkd = lib.mkDefault false;
          usePredictableInterfaceNames = lib.mkDefault true;

        };

        nix = {

          gc = {
            automatic = true;
            options = lib.mkDefault "--delete-older-than 30d";
          };

          optimise = {
            automatic = true;
          };

          settings = {
            max-free = lib.mkDefault (3 * 1024 * 1024 * 1024);
            min-free = lib.mkDefault (512 * 1024 * 1024);
          };

        };

        security = {

          apparmor.enable = true;

          lockKernelModules = true; # after boot loading not required on VMs

          sudo = {
            enable = true;
            execWheelOnly = lib.mkDefault true;
            extraConfig = ''
              Defaults lecture = never
            '';
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
            authorizedKeysInHomedir = false;
            authorizedKeysOnly = true;
            openFirewall = true;
          };

          smartd = {
            # ignore QEMU drives
            devices = flip genList 9 (n: {
              device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi${toString n}";
              options = "-d ignore";
            });
            # TODO this prevents invalid config files from failing smartd, but makes it run without any devices at start (no alternative implemented yet; mind NixOS does NOT validate the config on rebuild)
            extraOptions = [ "--quit=never" ];
            # TODO smartd.defaults.autodetected, set automatic self-tests
            # TODO smartd configure notifications
          };

        };

        system.autoUpgrade = {
          enable = true;
          allowReboot = true;
          fixedRandomDelay = true;
          flags = [
            # not supported by nixos-rebuild
            #"--no-allow-dirty"
            #"--no-use-registries"
            #"--no-update-lock-file"
          ];
          flake = lib.mkDefault "git+https://git.bananet.work/banananetwork/server#${config.networking.fqdnOrHostName}"; # ===SYNC:general/meta/repo/url===
          operation = "boot"; # change only on reboots
        };

        users = {
          mutableUsers = false;
          users.${cfg.userName} = {
            uid = 1000;
            description = cfg.userName;
            extraGroups = [
              (lib.mkIf config.networking.networkmanager.enable "networkmanager")
              "wheel"
            ];
            inherit (cfg) hashedPassword;
            isNormalUser = true;
            openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
          };
          users.root.openssh.authorizedKeys.keys = config.x-banananetwork.sshPublicKeys;
        };

        x-banananetwork = {

          allCommon.enable = true;
          debugMinimal.enable = true;
          # TODO think about
          #privacy.enable = true;

        };

        # TODO wishlist items (in prio order):
        # - ntfy.sh as mailer
        #   own script
        #   or e.g. https://stetsed.xyz/posts/email-notifications-with-ntfy-and-mailrise/
        #   & connect to: journalwatch, smartd
        # - add support for automatic boot assessment (will be added to 24.11)
        # - programs.atop.enable = true
        # - think about zramSwap
        # - NixOS test: ssh-audit
        # - networking.useNetworkd
        # - networking.tcpcrypt
        # environment.loginShellInit = "${lib.getExe resize}"; (see https://github.com/nix-community/srvos/blob/main/nixos/common/serial.nix)

      }

    ]
  );

}
