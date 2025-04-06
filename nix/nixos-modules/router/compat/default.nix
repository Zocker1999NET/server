# a set of modules ensuring compatibility with other networking service modules, e.g. VPNs
{ lib, ... }@flakeArg:
{ ... }:
let
  inherit (lib.modules) importsApplyMods;
in
{

  imports = importsApplyMods [
    # files
    ./tailscale.nix
  ];

}
