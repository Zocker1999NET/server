# a set of modules ensuring compatibility with other networking service modules, e.g. VPNs
{ lib, ... }@flakeArg:
{ ... }:
let
  inherit (lib.modules) importsApplyMods;
in
{

  _class = "nixos";

  imports = importsApplyMods [
    # files
    ./tailscale.nix
  ];

}
