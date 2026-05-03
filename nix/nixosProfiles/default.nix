{
  importApplyFlake,
  ...
}:
{
  _class = "flake";
  flake.nixosProfiles = {

    # "exclusive" profiles
    allHardware = ./allHardware.nix;
    blade = ./blade.nix;
    common = ./common.nix;
    installer = importApplyFlake ./installer.nix;
    pveGuest = ./pveGuest.nix;
    pveGuestHwSupport = ./pveGuestHwSupport.nix;

    # additions
    sambaServer = ./additions/sambaServer.nix;

  };
}
