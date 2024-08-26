{
  flake,
  inputs,
  lib,
  ...
}@flakeArg:
{ system, ... }@sysArg:
{

  # shortcut to fully configured secrix
  secrix =
    assert lib.assertMsg (system == "x86_64-linux") ''
      secrix is currently only compatible with x86_64-linux
    '';
    inputs.secrix.secrix flake;

}
