# makes for nice-behaving pve-guests with:
# - qemu-guest-agent & drivers
# - EFI booting
# - support for serial output (but graphic output should still work the same)
{
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  # Based on https://unix.stackexchange.com/questions/16578/resizable-serial-console-window
  resize = pkgs.writeShellScriptBin "resize" ''
    export PATH="${lib.getBin pkgs.coreutils}/bin"
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

  imports = [
    # from nixpkgs
    "${modulesPath}/profiles/qemu-guest.nix"
    # from here
    ./common.nix
  ];

  config = {

    boot = {

      # TODO duplicated by imported profile from nixpkgs
      initrd = {
        availableKernelModules = [
          "9p"
          "9pnet_virtio"
          "virtio_blk"
          "virtio_mmio"
          "virtio_net"
          "virtio_pci"
          "virtio_scsi"
        ];
        kernelModules = [
          "virtio_balloon"
          "virtio_console"
          "virtio_gpu"
          "virtio_rng"
        ];
      };

      kernelParams = [
        # show kernel log on serial
        "console=ttyS0,115200"
        # but use virtual tty as /dev/console (last entry)
        "console=tty0"
      ];

      # configure for EFI only
      loader = {
        efi.canTouchEfiVariables = true;
        grub.enable = lib.mkDefault false;
        grub.efiSupport = true; # in case grub is preferred for some reason
        systemd-boot.enable = lib.mkDefault true;
      };

    };

    environment.systemPackages = [ resize ];

    services = {
      qemuGuest.enable = true;
    };

    systemd.services."serial-getty@".environment.TERM = "xterm-256color";

    time.hardwareClockInLocalTime = false; # just to make sure

  };

}
