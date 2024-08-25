{ inputs, lib, ... }@flakeArg:
let
  nixpkgs = inputs.nixpkgs;

in
nixpkgs.lib
// {

  supportedSystems = builtins.attrNames inputs.nixpkgs.legacyPackages;

  systemSpecificVars = system: {
    pkgs = import inputs.nixpkgs { inherit system; };
    pkgs_unstable = import inputs.nixpkgs_unstable { inherit system; };
    inherit system;
  };

  forAllSystems =
    gen: inputs.nixpkgs.lib.genAttrs lib.supportedSystems (system: gen (lib.systemSpecificVars system));

}
