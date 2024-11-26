{ lib, ... }@flakeArg:
let
  importProfile = path: import path;
  importProfileMod = lib.importFlakeMod;
in
{
  allHardware = importProfile ./allHardware.nix;
  blade = importProfile ./blade.nix;
  common = importProfile ./common.nix;
  installer = importProfileMod ./installer.nix;
  pveGuest = importProfile ./pveGuest.nix;
  pveGuestHwSupport = importProfile ./pveGuestHwSupport.nix;
}
