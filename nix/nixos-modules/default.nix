{
  inputs,
  lib,
  outputs,
  self,
  ...
}@flakeArg:
let
  importModuleGroup = lib.importFlakeMod;
  importModule = path: { imports = lib.singleton path; };
in
{

  default = self.withDepends;

  # assertions checking for good practices
  assertions = importModule ./assertions;

  # this one includes all of my modules
  # - most of them only change things when enabled (e.g. x-banananetwork.*.enable)
  # - others only introduce small, reasonable changes if other module’s options are set, as reasonable defaults (if I intend to upstream them)
  # however, use on your own discretion
  banananetwork.imports = [
    # flake
    self.assertions
    # directories
    ./extends
    ./frontend
    ./improvedDefaults
    ./packages
    ./vmDisko
    # files
    ./autoUnfree.nix
    ./debugMinimal.nix
    ./graphics.nix
    ./options.nix
    ./privacy.nix
    ./secrix.nix
    ./sshSecurity.nix
    ./useable.nix
    ./vmCommon.nix
  ];

  # this one defines common options for my systems to my modules
  # you definitely do not want to use this
  myOptions = importModule ../myOptions.nix;

  # this one also includes required dependencies from flake inputs
  withDepends =
    { config, pkgs, ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        inputs.home-manager.nixosModules.home-manager
        inputs.impermanence.nixosModules.impermanence
        inputs.secrix.nixosModules.secrix
        self.banananetwork
      ];
      config = {
        nixpkgs.overlays = [
          outputs.overlays.backports
          outputs.overlays.fromFlake
        ];
      };
    };

  # from sub groups
  # NOTE: these will change possibly unsensible stuff just by importing them

  inherit (importModuleGroup ./overlays)
    # (make list commitable)
    systemd-radv-fadeout
    ;

}
