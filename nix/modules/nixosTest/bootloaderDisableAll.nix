# speeds up test building by not building bootloader configurations

{
  lib,
  ...
}:
let
  inherit (lib.modules) mkForce;
in
{
  _class = "nixosTest";
  defaults = {
    boot.loader = {
      grub.enable = mkForce false;
      systemd-boot.enable = mkForce false;
    };
  };
}
