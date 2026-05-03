{
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
{
  _class = "flake";
  # not really a complex function which could be part of lib
  # but a shortcut function
  # hence made available via flakeArg itself
  _module.args.importApplyFlake = path: importApply path flakeArg;
}
