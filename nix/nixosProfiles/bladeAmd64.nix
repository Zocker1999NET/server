# applicable to all systems running on bare hardware (x86_64-specific parts)

{
  lib,
  ...
}:
{

  _class = "nixos";

  imports = [
    # from here
    ./bladeAll.nix
  ];

  config = {

    # EFI by default
    boot.loader = {
      efi.canTouchEfiVariables = lib.mkDefault true;
      grub.memtest86.enable = lib.mkDefault true;
      systemd-boot = {
        enable = lib.mkDefault true;
        editor = lib.mkDefault true;
        memtest86.enable = lib.mkDefault true;
      };
    };

  };
}
