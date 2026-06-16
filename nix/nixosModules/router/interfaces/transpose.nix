# TODO (feature) general config tansposer between
{ globalArg, others, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  ifOpts = interface.options;
  inherit (builtins) concatMap foldl';
  inherit (lib) types;
  inherit (lib.attrsets)
    attrByPath
    getAttrs
    mapAttrsRecursiveCond
    recursiveUpdate
    setAttrByPath
    ;
  inherit (lib.lists) forEach;
  inherit (lib.modules) mkMerge;
  inherit (lib.options) isOption mkOption showOption;
  inherit (lib.strings) splitString;
  inherit (lib.trivial) flip pipe;
  # TODO suboptions (split with .) introduce infinite recursion
  transposable = map (splitString ".") [
    "dstnat.local"
    #
  ];
  # submodule important for preventing infinite recursion
  # (it resolves all possible sub-values statically, BEFORE any config is evaluated)
  transposeType = types.submodule {
    options = pipe transposable [
      (map (path: setAttrByPath path (attrByPath path { } ifOpts)))
      (foldl' recursiveUpdate { })
      (mapAttrsRecursiveCond (o: !isOption o) (
        loc: o:
        mkOption (
          flip getAttrs o [ "type" ]
          // {
            description = "same as {option}`ifCfg.${showOption loc}`";
            default = { };
            type = types.anything; # TODO debug/trace, remove
          }
        )
      ))
      (x: lib.debug.traceSeq (mapAttrsRecursiveCond (o: !isOption o) (_: builtins.attrNames) x) x)
    ];
  };
in
assert lib.asserts.assertMsg "transpose is WIP!" false;
{

  options = {
    transposeTo = mkOption {
      internal = true;
      type = types.attrsOf transposeType;
      default.example = { };
    };
    transposed = mkOption {
      internal = true;
      readOnly = true;
      type = transposeType;
      # TODO (minor) clone override prioritites
      # TODO (minor) clone order priorities
      default = pipe others [
        (concatMap (i: forEach ifCfg.effectiveGroups (g: i.transposeTo.${g} or { })))
        mkMerge
      ];
    };
  };

  config = pipe transposable [
    (map (path: setAttrByPath path (attrByPath path { } ifCfg.transposed)))
    (foldl' recursiveUpdate { })
  ];

}
