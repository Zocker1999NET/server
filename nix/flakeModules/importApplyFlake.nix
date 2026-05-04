{
  importApplyFlake,
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
      _module.args.importApplySystem = path: importApplyFlake path systemArg;
    };

}
