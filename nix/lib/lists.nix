{ lib, ... }@flakeArg:
let
  inherit (builtins)
    deepSeq
    foldl'
    groupBy
    mapAttrs
    ;
  inherit (lib.lists) optional singleton;
  inherit (lib.trivial) flip pipe;
in
{
  _class = "flake";
  flake.lib.lists = {

    groupByMult =
      groupers:
      # TODO (maybe) make more efficient by building up grouping function from right
      # from left
      # 0= (x: x) vals
      # 1= groupBy values[0] <0>
      # 2= mapAttrs (_: groupBy values[1]) <1>
      # 3= mapAttrs (_: mapAttrs (_: groupBy values[2])) <2>
      # from right
      # 1= (groupBy values[0])
      # 2= ...
      let
        nul = {
          mapper = x: x;
          result = [ ];
        };
        op =
          { mapper, result }:
          grouper: {
            mapper = fun: mapAttrs (_: mapper fun);
            result = result ++ singleton (mapper grouper);
          };
        list = map groupBy groupers;
        pipeList = (foldl' op nul list).result;
      in
      # catch errors while building groupers before values are passed through
      deepSeq pipeList (flip pipe pipeList);

    optionalNonNull = a: optional (a != null) a;

    # TODO check for lists.unique: if a groupBy variant would be more efficient
    #   - lists.unique has O(n^2)

  };
}
