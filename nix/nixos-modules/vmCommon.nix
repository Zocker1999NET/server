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
  inherit (lib.modules) mkRenamedOptionModule;
  inherit (lib.trivial) flip;
in
{

  imports = [
    (mkRenamedOptionModule
      [ "x-banananetwork" "vmCommon" "userName" ]
      [ "x-banananetwork" "serverCommon" "userName" ]
    )
    (mkRenamedOptionModule
      [ "x-banananetwork" "vmCommon" "hashedPassword" ]
      [ "x-banananetwork" "serverCommon" "hashedPassword" ]
    )
  ];

  options = {

    x-banananetwork.vmCommon = {

      enable = lib.mkEnableOption ''
        settings for all my VMs
      '';

    };

  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [

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
            logRefusedConnections = lib.mkDefault false;
            # TODO
          };

          useDHCP = lib.mkDefault true;
          useNetworkd = lib.mkDefault false;
          usePredictableInterfaceNames = lib.mkDefault true;

        };

        services = {

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

        x-banananetwork = {

          serverCommon.enable = true;
          # TODO think about
          #privacy.enable = true;

        };

        # TODO wishlist items (in prio order; some for serverCommon.nix):
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
