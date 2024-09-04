{ inputs, lib, ... }@flakeArg:
let
  nixpkgs = inputs.nixpkgs;
  libO = nixpkgs.lib;
in
libO
// {

  supportedSystems = builtins.attrNames nixpkgs.legacyPackages;

  systemSpecificVars = system: {
    pkgs = import nixpkgs { inherit system; };
    pkgs_unstable = import inputs.nixpkgs_unstable { inherit system; };
    inherit system;
  };

  forAllSystems =
    gen: lib.genAttrs lib.supportedSystems (system: gen (lib.systemSpecificVars system));

  importFlakeModWithSystem = path: lib.forAllSystems (lib.importFlakeMod path);

}
