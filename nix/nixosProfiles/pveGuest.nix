# makes for nice-behaving pve-guests
# extends pveGuestSupport by adding:
# - EFI booting
# ONLY for installed systems
{ lib, ... }:
{

  _class = "nixos";

  imports = [
    # from here
    ./common.nix
    ./pveGuestHwSupport.nix
  ];

  config = {

    # configure for EFI only
    boot.loader = {
      efi.canTouchEfiVariables = true;
      grub.enable = lib.mkDefault false;
      grub.efiSupport = true; # in case grub is preferred for some reason
      systemd-boot.enable = lib.mkDefault true;
    };

  };

}
