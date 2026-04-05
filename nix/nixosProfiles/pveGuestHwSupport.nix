# makes for nice-behaving pve-guests:
# - qemu-guest-agent & drivers
# - support for serial output (but graphic output should still work the same)
# works for installers as well (does NOT include common.nix)
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

  _class = "nixos";

  imports = [
    # from nixpkgs
    "${modulesPath}/profiles/qemu-guest.nix"
  ];

  config = {

    boot = {

      # TODO probably until https://github.com/NixOS/nixpkgs/issues/340086
      initrd.availableKernelModules = lib.singleton "virtio_iommu";

      kernelParams = [
        # show kernel log on serial
        "console=ttyS0,115200"
        # but use virtual tty as /dev/console (last entry)
        "console=tty0"
      ];

    };

    environment.systemPackages = [ resize ];

    services = {
      qemuGuest.enable = true;
    };

    systemd.services."serial-getty@".environment.TERM = "xterm-256color";

    time.hardwareClockInLocalTime = false; # just to make sure

  };

}
