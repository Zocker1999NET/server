{ lib, ... }@flakeArg:
let
  importProfile = path: import path;
  importProfileMod = lib.importFlakeMod;
in
{
  blade = importProfile ./blade.nix;
  common = importProfile ./common.nix;
  pveGuest = importProfile ./pveGuest.nix;
}
