{
  lib,
  ...
}:
let
  inherit (lib) types;
  inherit (lib.options) literalExpression mkOption;

  libType =
    with types;
    lazyAttrsOf (
      either
        # order of args important to allow merging attrs
        (lazyAttrsOf raw)
        raw
    );
in
{
  _class = "flake";
  options.flake.lib = mkOption {
    description = ''
      Library output.

      Useful to expose nix functions so others can use them in their flakes.

      Type is defined to allow composing up to 1 attrset layer down
      (e.g. `lib.attrsets`)
      by merging multiple definitions.
    '';
    type = libType;
    default = { };
    example = literalExpression ''
      rec {
        strings = {
          concatArbitrary = sep: l: with builtins; concatStringsSep sep (map toString l);
        };
        concatArbitrary = strings.concatArbitrary;
      }
    '';
  };
}
