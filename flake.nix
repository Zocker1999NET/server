{
  description = "banananet.work Server & Deployment Controller environment";

  inputs = {

    # packages repositories
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs_unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # required submodules
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-24.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";
    secrix = {
      # TODO revert after my pulls are merged: https://github.com/Platonic-Systems/secrix/pulls/Zocker1999NET
      #url = "github:Platonic-Systems/secrix";
      url = "github:Zocker1999NET/secrix/release-bnet";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    crane.url = "github:ipetkov/crane";

    # required for configs
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    unattended-installer = {
      url = "github:chrillefkr/nixos-unattended-installer";
      inputs.disko.follows = "disko";
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

    };
}
