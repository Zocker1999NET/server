{
  inputs,
  lib,
  libBNet,
  ...
}@flakeArg:
let
  inherit (inputs) nixpkgs;
  inherit (builtins) isAttrs;
  inherit (lib.attrsets) genAttrs;
  inherit (lib.modules) mkMerge;
  inherit (libBNet)
    forAllSystems
    importFlakeMod
    supportedSystems
    systemSpecificVars
    ;
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

  flake.lib = mkMerge [

    # be a drop-in replacement
    nixpkgs.lib

    {

      autoExtend =
        upstream: name: obj:
        (upstream.${name} or { }) // (if isAttrs obj then obj else importFlakeMod obj);

      forAllSystems = gen: genAttrs supportedSystems (system: gen (systemSpecificVars system));

      importFlakeModWithSystem = path: forAllSystems (importFlakeMod path);

      # restricted to run nix flake show
      supportedSystems = [
        "x86_64-linux"
      ];

      systemSpecificVars = system: {
        pkgs = import nixpkgs { inherit system; };
        pkgs_unstable = import inputs.nixpkgs_unstable { inherit system; };
        inherit system;
      };

    }

  ];

}
