let
  inherit (builtins) attrValues;

  # modules which are auto-imported to this flake
  publicModules = {
    nixosProfiles = ./nixosProfiles.nix;
  };

  privateModules = [
    ./importApplyFlake.nix
  ];

in
{
  _class = "flake";
  imports = attrValues publicModules ++ privateModules;
  flake.flakeModules = publicModules;
}
