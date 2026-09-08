{
  importApplyFlake,
  ...
}:
{
  _class = "flake";
  flake.nixosProfiles = {

    # "exclusive" profiles
    allHardware = ./allHardware.nix;
    # legacy alias: `blade` used to be the x86_64 bare-metal profile
    # TODO add deprecation warning & fade out
    blade = ./bladeAmd64.nix;
    bladeAll = ./bladeAll.nix;
    bladeAmd64 = ./bladeAmd64.nix;
    common = ./common.nix;
    installer = importApplyFlake ./installer.nix;
    pveGuest = ./pveGuest.nix;
    pveGuestHwSupport = ./pveGuestHwSupport.nix;

    # additions
    nixSshBuilder = ./additions/nixSshBuilder.nix;
    sambaServer = ./additions/sambaServer.nix;

  };
}
