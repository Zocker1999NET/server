{ ... }@flakeArg:
let
  inherit (builtins) attrValues mapAttrs;
in
{
  _class = "flake";
  flake.lib.attrsets = {

    # TODO (upstream, performance)
    mapAttrsToList = f: attrs: attrValues (mapAttrs f attrs);

  };
}
