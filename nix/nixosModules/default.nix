{
  inputs,
  importApplyFlake,
  self,
  ...
}@flakeArg:
let
  selfMods = self.nixosModules;
in
{

  _class = "flake";

  imports = [
    ./overlays
  ];

  flake.nixosModules = {

    default = selfMods.withDepends;

    # assertions checking for good practices
    assertions = ./assertions;

    # this one includes most of my modules
    # - most of them only change things when enabled (e.g. x-banananetwork.*.enable)
    # - others only introduce small, reasonable changes if other module’s options are set, as reasonable defaults (if I intend to upstream them)
    # however, use on your own discretion
    banananetwork.imports = [
      # flake
      selfMods.assertions
      # directories
      ./autoUnfree
      ./dynamicIssue
      ./extends
      ./frontend
      ./improvedDefaults
      ./packages
      ./useable
      ./vmDisko
      # files
      (importApplyFlake ./backports.nix)
      ./cachedFlakesDevShell.nix
      ./debugMinimal.nix
      ./graphics.nix
      ./log-wakeup-reason.nix
      ./memory.nix
      ./options.nix
      ./permittedInsecure.nix
      ./privacy.nix
      ./secrix.nix
      ./serverCommon.nix
      ./sshHostKeyPropagation.nix
      ./vmCommon.nix
      ./zfsServer.nix
    ];

    # this one defines common options for my systems to my modules
    # you definitely do not want to use this
    myOptions = importApplyFlake ../myOptions.nix;

    # this one also includes required dependencies from flake inputs
    withDepends =
      { config, pkgs, ... }:
      {
        imports = [
          inputs.disko.nixosModules.disko
          inputs.home-manager.nixosModules.home-manager
          inputs.impermanence.nixosModules.impermanence
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.secrix.nixosModules.secrix
          selfMods.banananetwork
        ];
        config.nixpkgs.overlays = with self.overlays; [
          default
        ];
      };

    # my router module
    # - for documentation, see ./router/README.md
    # - served separatedly because it is large & because it modifies systemd via an overlay
    router = (importApplyFlake ./router);

  };

}
