{ ... }@flakeArg:
let
  importProfile = path: import path;
in
{
  blade = importProfile ./blade.nix;
  common = importProfile ./common.nix;
  pveGuest = importProfile ./pveGuest.nix;
}
