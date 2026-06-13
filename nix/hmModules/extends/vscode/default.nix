{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib.attrsets) genAttrs;
  inherit (lib.lists) singleton;
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf submodule;
  # quasi-copied from https://github.com/nix-community/home-manager/blob/8355f0a16b2dbb06a97959a918af5b239bbe05ae/modules/programs/vscode/default.nix#L11-L17
  forkModules = [
    "vscode" # do not forget the original!
    "vscodium"
    "cursor"
    "windsurf"
    "kiro"
    "antigravity"
  ];
in
{
  _class = "homeManager";
  # extend all forks simultaneously
  options.programs = genAttrs forkModules (_: {

    profiles = mkOption {
      type = attrsOf (submodule {
        imports = singleton ./profiles.nix;
        config._module.args = {
          inherit pkgs;
        };
      });
    };

  });

}
