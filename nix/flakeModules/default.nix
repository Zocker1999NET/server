let
  inherit (builtins) attrValues;

  # modules which are auto-imported to this flake
  publicModules = {
    allModuleArgs = ./allModuleArgs.nix;
    importApplyFlake = ./importApplyFlake.nix;
    nixosProfiles = ./nixosProfiles.nix;
  };

  privateModules = [
  ];

in
{
  _class = "flake";
  imports = attrValues publicModules ++ privateModules;
  flake.flakeModules = publicModules;
}
