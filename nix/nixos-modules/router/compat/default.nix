# a set of modules ensuring compatibility with other networking service modules, e.g. VPNs
{ libBNet, ... }@flakeArg:
{ ... }:
let
  inherit (libBNet.modules) importsApplyMods;
in
{

  _class = "nixos";

  imports = importsApplyMods [
    # files
    ./tailscale.nix
  ];

}
