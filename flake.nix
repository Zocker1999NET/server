{
  description = "banananet.work Server & Deployment Controller environment";

  inputs = {

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    # packages repositories
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs_unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # required submodules
    disko = {
      # TODO maybe refer to releases instead of master
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
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
    flake-parts.lib.mkFlake { inherit inputs; } {

      # args for flake-parts modules
      _module.args = {
        libBNet = self.outputs.lib;
      };
      perSystem =
        { inputs', ... }:
        {
          _module.args = {
            pkgs_unstable = inputs'.nixpkgs_unstable.legacyPackages;
          };
        };

      imports = [
        # extensions from inputs
        inputs.flake-parts.flakeModules.flakeModules
        inputs.flake-parts.flakeModules.modules
        inputs.home-manager.flakeModules.home-manager
        # my modules
        ./nix/apps
        ./nix/checks
        ./nix/devShells
        ./nix/flakeModules
        ./nix/hmModules
        ./nix/lib
        ./nix/modules
        ./nix/nixos
        ./nix/nixosModules
        ./nix/nixosProfiles
        ./nix/overlays
        ./nix/packages
      ];
    };
}
