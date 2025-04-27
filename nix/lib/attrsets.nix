{ ... }@flakeArg:
let
  inherit (builtins) attrValues mapAttrs;
in
{

  # TODO (upstream, performance)
  mapAttrsToList = f: attrs: attrValues (mapAttrs f attrs);

}
