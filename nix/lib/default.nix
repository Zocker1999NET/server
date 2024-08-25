{ inputs, lib, ... }@flakeArg:
let
  nixpkgs = inputs.nixpkgs;

in
nixpkgs.lib
// {

}
