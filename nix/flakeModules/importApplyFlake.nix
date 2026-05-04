{
  importApplyFlake,
  importWithFlake,
  lib,
  # for auto-detection reasons implemented in the module system,
  # this one needs to mention some args used by importApplyFlake consumers,
  # hence here is a list of all (imaginable) dependencies:
  inputs,
  libBNet,
  self,
  ...
}@flakeArg:
let
  inherit (lib.modules) importApply;
in
# not really complex functions which could be part of lib
# but useful shortcuts hence made available via flakeArg / systemArg themselves
{

  _class = "flake";

  # variant for non-modules / everything else
  _module.args.importWithFlake = path: import path flakeArg;
  # variant for module system modules
  _module.args.importApplyFlake = path: importApply path flakeArg;

  perSystem =
    {
      config,
      ...
    }:
    let
      # flake-parts exposes this one for us
      systemArg = config.allModuleArgs;
    in
    {
      # variant for non-modules / everything else
      _module.args.importWithSystem = path: importWithFlake path systemArg;
      # variant for module system modules
      _module.args.importApplySystem = path: importApplyFlake path systemArg;
    };

}
