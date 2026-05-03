{ inputs, lib, ... }@flakeArg:
let
  inherit (inputs) nixpkgs;
  inherit (builtins) isAttrs mapAttrs;
  inherit (lib) autoExtend importFlakeMod;
in

# be a drop-in replacement
nixpkgs.lib

# groups
// mapAttrs (autoExtend nixpkgs.lib) {
  attrsets = ./attrsets.nix;
  backport = ./backport.nix;
  lists = ./lists.nix;
  math = ./math.nix;
  modules = ./modules.nix;
  network = ./network.nix;
  options = ./options.nix;
  strings = ./strings.nix;
  trivial = ./trivial.nix;
  types = ./types.nix;
  x-banananetwork-unused = ./unused.nix;
}

# functions
// {

  autoExtend =
    upstream: name: obj:
    (upstream.${name} or { }) // (if isAttrs obj then obj else importFlakeMod obj);

  # restricted to run nix flake show
  supportedSystems = [
    "x86_64-linux"
  ];

  systemSpecificVars = system: {
    pkgs = import nixpkgs { inherit system; };
    pkgs_unstable = import inputs.nixpkgs_unstable { inherit system; };
    inherit system;
  };

  forAllSystems =
    gen: lib.genAttrs lib.supportedSystems (system: gen (lib.systemSpecificVars system));

  importFlakeModWithSystem = path: lib.forAllSystems (lib.importFlakeMod path);

  # TODO sort

}
