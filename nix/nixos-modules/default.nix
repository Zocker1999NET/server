{
  inputs,
  lib,
  outputs,
  self,
  ...
}@flakeArg:
{

  default = self.withDepends;

  # this one includes all of my modules
  # - most of them only change things when enabled (e.g. x-banananetwork.*.enable)
  # - others only introduce small, reasonable changes if other module’s options are set, as reasonable defaults (if I intend to upstream them)
  # however, use on your own discretion
  banananetwork.imports = [
    # directories
    ./extends
    ./frontend
    ./improvedDefaults
    # files
    ./allCommon.nix
    ./autoUnfree.nix
    ./debugMinimal.nix
    ./graphics.nix
    ./hwCommon.nix
    ./kernel.nix
    ./options.nix
    ./privacy.nix
    ./secrix.nix
    ./sshSecurity.nix
    ./useable.nix
    ./vmCommon.nix
  ];

  # this one defines common options for my systems to my modules
  # you definitely do not want to use this
  myOptions = import ../myOptions.nix;

  # this one also includes required dependencies from flake inputs
  withDepends =
    { config, pkgs, ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        inputs.home-manager.nixosModules.home-manager
        inputs.impermanence.nixosModules.impermanence
        inputs.secrix.nixosModules.secrix
        outputs.nixosModules.banananetwork
      ];
      config = {
        nixpkgs.overlays = lib.singleton outputs.overlays.backports;
      };
    };

}
