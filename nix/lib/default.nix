{
  inputs,
  ...
}@flakeArg:
let
  inherit (inputs) nixpkgs;
in
{

  _class = "flake";

  imports = [
    ./attrsets.nix
    ./backport.nix
    ./lists.nix
    ./math.nix
    ./modules.nix
    ./network.nix
    ./options.nix
    ./strings.nix
    ./trivial.nix
    ./types.nix
    ./unused.nix
  ];

  # be a drop-in replacement
  flake.lib = nixpkgs.lib;

}
