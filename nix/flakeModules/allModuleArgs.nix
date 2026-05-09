# inspired by https://github.com/hercules-ci/flake-parts/blob/0678d8986be1661af6bb555f3489f2fdfc31f6ff/modules/withSystem.nix#L16
{
  config,
  lib,
  options,
  specialArgs,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.options) mkOption;
in
{
  _class = "flake";
  options = {
    allModuleArgs = mkOption {
      description = "Internal option that exposes _module.args.";
      type = with types; lazyAttrsOf raw;
      internal = true;
      readOnly = true;
      default = config._module.args // specialArgs // { inherit config lib options; };
    };
  };
}
