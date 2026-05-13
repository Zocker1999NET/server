{ inputs, lib, ... }@flakeArg:
let
  inherit (lib.backport) backportNixpkg;
in
{
  _class = "flake";
  flake.lib.trivial = {

  }
  # backports
  // backportNixpkg "lib.trivial" [
    #
  ];
}
