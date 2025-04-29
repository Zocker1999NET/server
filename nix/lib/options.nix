{ lib, ... }@flakeArg:
let
  inherit (lib) types;
  inherit (lib.options) mkOption;
in
{

  mkSubmoduleExtension = mod: mkOption { type = types.subCombined mod; };
  mkSubmoduleAttrsExtension = mod: mkOption { type = types.attrsOf (types.subCombined mod); };
  mkSubmoduleListExtension = mod: mkOption { type = types.listOf (types.subCombined mod); };

}
