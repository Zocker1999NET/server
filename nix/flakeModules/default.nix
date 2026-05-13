let
  inherit (builtins) attrValues;

  # modules which are auto-imported to this flake
  publicModules = {
    allModuleArgs = ./allModuleArgs.nix;
    checkBuildable = ./checkBuildable.nix;
    flakeSpecialArgs = ./flakeSpecialArgs.nix;
    importApplyFlake = ./importApplyFlake.nix;
    lib = ./lib.nix;
    nixosProfiles = ./nixosProfiles.nix;
    orderedInputs = ./orderedInputs.nix;
  };

  privateModules = [
    ./_ciTargets.nix
    ./_configuration.nix
  ];

in
{
  _class = "flake";
  imports = attrValues publicModules ++ privateModules;
  flake.flakeModules = publicModules;
}
