{ inputs, lib, ... }@flakeArg:
let
  inherit (builtins) isPath isString;
  inherit (lib.backport) backportNixpkg;
  inherit (lib.modules) importApply importsApplyIf mkOverride;
in
{

  # TODO upstream
  importsApplyIf = staticArg: map (i: if isPath i || isString i then importApply i staticArg else i);

  importApplyMod = path: importApply path flakeArg;
  importsApplyMods = importsApplyIf flakeArg;

  # TODO upstream
  mkTestOverride = mkOverride 55;

}
# backports
// backportNixpkg "lib.modules" [
  #
  "importApply"
]
