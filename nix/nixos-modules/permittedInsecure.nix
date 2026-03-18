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
  inherit (lib.trivial) flip pipe;
  convertEntry = name: version: optional (versionAtLeast version pkgs.lib.version) name;
  convertAttrs = flip pipe [
    (mapAttrsToList convertEntry)
    concatLists
  ];
  cfg = config.nixpkgs.permitInsecurePackagesUntil;
in
{
  options.nixpkgs.permitInsecurePackagesUntil = mkOption {
    description = ''
      Permit insecure packages until a given NixOS major version.

      This may be useful to limit the impact of permitted insecure packages
      only until the next NixOS major upgrade
      without relying on deleting such entry manually.

      To limit a permit only for the current major release
      (so the permit stops working after the current version),
      use the version number of the current major release.
    '';
    type = with types; attrsOf str;
    default = { };
    example = {
      "temporary-insecure-package" = "25.11";
    };
  };

  config.nixpkgs.config = mkIf (cfg != { }) {
    permittedInsecurePackages = convertAttrs cfg;
  };

}
