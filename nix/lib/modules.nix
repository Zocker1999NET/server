{ inputs, lib, ... }@flakeArg:
let
  inherit (lib.backport) backportNixpkg;
  inherit (lib.modules) mkOverride;
in
{

  mkTestOverride = mkOverride 55;

}
# backports
// backportNixpkg "lib.modules" [
  #
  "importApply"
]
