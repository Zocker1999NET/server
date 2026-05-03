{ libBNet, ... }@flakeArg:
let
  importProfile = path: import path;
  importProfileMod = libBNet.importFlakeMod;
in
{

  # "exclusive" profiles
  allHardware = importProfile ./allHardware.nix;
  blade = importProfile ./blade.nix;
  common = importProfile ./common.nix;
  installer = importProfileMod ./installer.nix;
  pveGuest = importProfile ./pveGuest.nix;
  pveGuestHwSupport = importProfile ./pveGuestHwSupport.nix;

  # additions
  sambaServer = importProfile ./additions/sambaServer.nix;

}
