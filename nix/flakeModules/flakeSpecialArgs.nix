{ lib, ... }:
let
  inherit (lib) types;
  inherit (lib.options) literalExpression mkOption;
in
{
  _class = "flake";
  options = {
    flakeSpecialArgs = mkOption {
      description = ''
        Holds a set of specialArgs
        which might be used as such
        by module system invocations used in this flake,
        e.g. in nixosSystem, runNixOSTest or home-manager.

        It is intended to contain flake-special variables.

        This is more or less just a fancy way
        to have this as a shared variable across a flake.
      '';
      type = with types; lazyAttrsOf raw;
      default = { };
      example = literalExpression ''
        # values from flake-parts module args, i.e. at top is:
        # { inputs, outputs, self, ... }@flakeArg:
        {
          inherit flakeArg;
          flake = self;
          myLib = outputs.lib;
        }
      '';
    };
  };
}
