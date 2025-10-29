{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) concatLists;
  inherit (lib) types;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) optional;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption;
  inherit (lib.strings) versionAtLeast;
  convertEntry = name: version: optional (versionAtLeast version pkgs.lib.version) name;
  convertAttrs = attrs: concatLists (mapAttrsToList convertEntry attrs);
  cfg = config.nixpkgs.permitInsecurePackagesUntil;
in
{
  options.nixpkgs.permitInsecurePackagesUntil = mkOption {
    type = with types; attrsOf str;
    default = { };
  };

  config.nixpkgs.config = mkIf (cfg != { }) {
    permittedInsecurePackages = (convertAttrs cfg);
  };

}
