# applicable to all service VMs running on a hypervisor (currently Proxmox/QEMU assumed)

{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.x-banananetwork.vmCommon;
  # Based on https://unix.stackexchange.com/questions/16578/resizable-serial-console-window
  resize = pkgs.writeShellScriptBin "resize" ''
    export PATH="${pkgs.coreutils}/bin"
    if [ ! -t 0 ]; then
      # not a interactive...
      exit 0
    fi
    TTY="$(tty)"
    if [[ "$TTY" != /dev/ttyS* ]] && [[ "$TTY" != /dev/ttyAMA* ]] && [[ "$TTY" != /dev/ttySIF* ]]; then
      # probably not a known serial console, we could make this check more
      # precise by using `setserial` but this would require some additional
      # dependency
      exit 0
    fi
    old=$(stty -g)
    stty raw -echo min 0 time 5

    printf '\0337\033[r\033[999;999H\033[6n\0338' > /dev/tty
    IFS='[;R' read -r _ rows cols _ < /dev/tty

    stty "$old"
    stty cols "$cols" rows "$rows"
  '';
in
{

  options = {

    x-banananetwork.vmCommon = {

      enable = lib.mkEnableOption ''
        settings common to all hosts running in VMs
      '';

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
          rebootWindow.upper = "04:00";
        };

        nix.gc = {
          # could take longer
          dates = "04:15";
          randomizedDelaySec = "30min";
        };

        nix.optimise = {
          # should not take long because of auto-optimise-store
          dates = "05:30";
        };

      }

      {

        # all other options

        boot = {

          kernelParams = "console=ttyS0,115200";

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

        console.keyMap = "de";

        # for fast debugging of systems, keep small
        environment.systemPackages = [ resize ];

        networking = {

          firewall = {
            logRefusedConnections = false;
            # TODO
          };

          useDHCP = true;
          useNetworkd = lib.mkDefault false;
          usePredictableInterfaceNames = true;

        };

        nix = {

          gc = {
            automatic = true;
            options = "--delete-older-than 30d";
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

          qemuGuest.enable = true;

          openssh = {
            enable = true;
            authorizedKeysInHomedir = false;
            authorizedKeysOnly = true;
            openFirewall = true;
          };

        };

        sound.enable = false;

        system.autoUpgrade = {
          enable = true;
          allowReboot = true;
          fixedRandomDelay = true;
          flags = [
            "--no-allow-dirty"
            "--no-use-registries"
            "--no-update-lock-file"
          ];
          flake = lib.mkDefault "git+https://git.bananet.work/banananetwork/server#${config.networking.fqdnOrHostName}"; # ===SYNC:general/meta/repo/url===
          operation = "boot"; # change only on reboots
        };

        systemd.services."serial-getty@".environment.TERM = "xterm-256color";

        time.hardwareClockInLocalTime = false; # just to make sure

        x-banananetwork = {

          allCommon.enable = true;
          debugMinimal.enable = true;
          # TODO think about
          #privacy.enable = true;

        };

        # TODO disko config, see https://github.com/nix-community/disko/blob/master/docs/INDEX.md

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
        # environment.loginShellInit = "${resize}/bin/resize"; (see https://github.com/nix-community/srvos/blob/main/nixos/common/serial.nix)

      }

    ]
  );

}
