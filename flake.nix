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
    inputs@{ flake-parts, self, ... }:
    let
      inherit (self) outputs;
      inherit (outputs) lib;
      inherit (outputs.libAnchors) importFlakeMod;
      inherit (lib) importFlakeModWithSystem;

      # every flake "submodule" gets this passed:
      flakeArg = {
        # Usage in submodule:
        # { ... }@flakeArg: { }
        # add "..." this so new ones can easily be added
        flake = self; # full flake reflection
        # tools / shortcuts
        inherit (inputs.nixpkgs) lib;
        # custom lib (nixpkgs lib combined with mine)
        libBNet = lib;
        inherit
          # flake refs
          inputs # evaluated inputs
          outputs # evaluated outputs
          ;
      };

    in
    flake-parts.lib.mkFlake { inherit inputs; } {

      _module.args = {
        libBNet = lib;
      };

      perSystem =
        { system, ... }:
        {
          _module.args.pkgs_unstable = inputs.nixpkgs_unstable.legacyPackages.${system};
        };

      imports = [
        # extensions from inputs
        inputs.flake-parts.flakeModules.flakeModules
        # my modules
        ./nix/apps
        ./nix/devShells
        ./nix/flakeModules
        ./nix/nixosModules
        ./nix/nixosProfiles
      ];

      systems = [ "x86_64-linux" ];

      flake = {

        checks = outputs.nixosTests;

        lib = outputs.libAnchors // importFlakeMod ./nix/lib;

        libAnchors = rec {
          initFlakeMod = mod: mod flakeArg;
          importFlakeMod = path: initFlakeMod (import path);
        };

        homeManagerModules = importFlakeMod ./nix/hmModules;

        nixosConfigurations = importFlakeMod ./nix/nixos;

        nixosTests = importFlakeModWithSystem ./nix/nixosTests;

        overlays = importFlakeMod ./nix/overlays;

        packages = importFlakeModWithSystem ./nix/packages;

        # for auto update mechanism
        inherit (importFlakeMod ./inputSorter.nix) orderedInputs;

      };
    };
}
