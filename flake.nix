{
  description = "banananet.work Server & Deployment Controller environment";


  inputs = {

    # packages repositories
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs_unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # required submodules
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence.url = "github:nix-community/impermanence";

  };


  outputs = { self, ... }@inputs:
    let
      inherit (self) outputs;
      # constants
      system = "x86_64-linux";
      # package repositories
      pkgs = import inputs.nixpkgs { inherit system; };
      pkgs_unstable = import inputs.nixpkgs_unstable { inherit system; };
    in
    {


      nixosModules = {

        # this one includes all of my modules
        # - most of them only change things when enabled (e.g. x-banananetwork.*.enable)
        # - others only introduce small, reasonable changes if other module’s options are set, as reasonable defaults (if I intend to upstream them)
        # however, use on your own discretion
        banananetwork = import ./nix/nixos-modules;

        # this one also includes required dependencies from flake inputs
        withDepends = {
          imports = [
            inputs.home-manager.nixosModules.home-manager
            inputs.impermanence.nixosModules.impermanence
            outputs.nixosModules.banananetwork
          ];
        };

      };


      devShells."${system}".default =
        let
          pkgs = pkgs_unstable;
        in
        pkgs.mkShell
          {
            packages = with pkgs; [
              curl
              rsync
              opentofu
              terranix
            ];
          };


    };
}
