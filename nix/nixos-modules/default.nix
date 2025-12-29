{
  inputs,
  lib,
  outputs,
  self,
  ...
}@flakeArg:
let
  inherit (lib.modules) importApplyMod;
  importModuleGroup = lib.importFlakeMod;
  importModule = path: { imports = lib.singleton path; };
in
{

  default = self.withDepends;

  # assertions checking for good practices
  assertions = importModule ./assertions;

  # this one includes most of my modules
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
    (importApplyMod ./backports.nix)
    ./debugMinimal.nix
    ./getty-helpLine-sshPublicHostKey.nix
    ./graphics.nix
    ./log-wakeup-reason.nix
    ./memory.nix
    ./options.nix
    ./permittedInsecure.nix
    ./privacy.nix
    ./secrix.nix
    ./serverCommon.nix
    ./useable.nix
    ./vmCommon.nix
    ./zfsServer.nix
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
        inputs.lanzaboote.nixosModules.lanzaboote
        inputs.secrix.nixosModules.secrix
        self.banananetwork
      ];
      config = {
        nixpkgs.overlays = [
          outputs.overlays.backports
          outputs.overlays.fromFlake
          outputs.overlays.taskwarrior3-customs
          outputs.overlays.upgrades
        ];
      };
    };

  # my router module
  # - for documentation, see ./router/README.md
  # - served separatedly because it is large & because it modifies systemd via an overlay
  router = (importApplyMod ./router);

  # from sub groups
  # NOTE: these will change possibly unsensible stuff just by importing them

  inherit (importModuleGroup ./overlays)
    # (make list commitable)
    systemd-radv-fadeout
    ;

}
