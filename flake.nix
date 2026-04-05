{
  description = "banananet.work Server & Deployment Controller environment";

  inputs = {

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # packages repositories
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs_unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # required submodules
    disko = {
      # TODO maybe refer to releases instead of master
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs = {
        home-manager.follows = "home-manager";
        nixpkgs.follows = "nixpkgs";
      };
    };
    lanzaboote = {
      url = "github:nix-community/lanzaboote";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        # do not follow crane (using it for different purposes)
      };
    };
    secrix = {
      url = "github:Platonic-Systems/secrix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    crane.url = "github:ipetkov/crane";

    # required for configs
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    disko-install-menu = {
      url = "github:Zocker1999NET/disko-install-menu";
      inputs.disko.follows = "disko";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # single packages

    pkgs_streamlined-client = {
      url = "github:Zocker1999NET/entertainment-decider?dir=desktop-client";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # TODO experiment with
    # - https://git.sr.ht/~msalerno/wirenix

  };

  outputs =
    { self, ... }@inputs:
    let
      inherit (self) outputs;
      inherit (outputs) lib;
      # every flake "submodule" gets this passed:
      flakeArg = {
        # Usage in submodule:
        # { ... }@flakeArg: { }
        # add "..." this so new ones can easily be added
        flake = self; # full flake reflection
        inherit
          # tools / shortcuts
          lib # nixpkgs & my lib combined
          # flake refs
          inputs # evaluated inputs
          outputs # evaluated outputs
          ;
        # self: the module’s result, via self-reflection
      };
      inherit (outputs.libAnchors) importFlakeMod;
      inherit (lib) importFlakeModWithSystem;
    in
    {

      apps = importFlakeModWithSystem ./nix/apps;

      checks = outputs.nixosTests;

      devShells = importFlakeModWithSystem ./nix/devShells;

      homeManagerModules = importFlakeMod ./nix/hmModules;

      lib = outputs.libAnchors // importFlakeMod ./nix/lib;

      # anchors required for importing modules
      libAnchors =
        let
          lib = inputs.nixpkgs.lib;
          inherit (lib.asserts) assertMsg;
        in
        rec {
          # ({?} -> ?) -> {?} -> ?
          # gives a function access to its own return value
          # by adding it to its first argument (assuming that’s an attrset)
          reflect =
            fun: attrs:
            # TODO is there a more official way?
            assert assertMsg (builtins.isAttrs attrs) ''
              expected a set, got an ${builtins.typeOf attrs}
            '';
            assert assertMsg (!attrs ? "self") ''
              reflect argument already contains a self attribute
            '';
            let
              outputs = fun (attrs // { self = result; });
              result = outputs;
            in
            result;
          initFlakeMod = mod: reflect mod flakeArg;
          importFlakeMod = path: initFlakeMod (import path);
        };

      nixosConfigurations = importFlakeMod ./nix/nixos;

      nixosModules = importFlakeMod ./nix/nixos-modules;

      nixosProfiles = importFlakeMod ./nix/nixosProfiles;

      nixosTests = importFlakeModWithSystem ./nix/nixosTests;

      overlays = importFlakeMod ./nix/overlays;

      packages = importFlakeModWithSystem ./nix/packages;

      # for auto update mechanism
      inherit (importFlakeMod ./inputSorter.nix) orderedInputs;

    };
}
