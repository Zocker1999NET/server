# helps upholding some assumptions the test driver makes
# but which could be overwritten by e.g. integration tests

{
  lib,
  ...
}:
let
  inherit (lib.modules) mkForce;
in
{
  _class = "nixosTest";
  defaults = {
    # required for test driver to send correct chars to TTY
    console.keyMap = mkForce "us";
  };
}
