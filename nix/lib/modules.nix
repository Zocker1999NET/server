{ inputs, lib, ... }@flakeArg:
let
  inherit (lib.modules) mkOverride;
in
{

  mkTestOverride = mkOverride 55;

}
