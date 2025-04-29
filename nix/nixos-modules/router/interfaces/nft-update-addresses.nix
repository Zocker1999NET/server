{ globalArg, others, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  nuaOpts = interface.options.nft-update-addresses;
  inherit (builtins) concatMap filter;
  inherit (lib) types;
  inherit (lib.modules) mkMerge;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) flip pipe;
in
{

  options.nft-update-addresses = {
    config = mkOption {
      type = types.attrsOf types.anything; # TODO reuse type from globalArg via options reflection
      internal = true;
      default = { };
    };
    for = mkOption {
      type = types.attrsOf nuaOpts.config.type;
      internal = true;
      default = { };
    };
  };

  config = {
    # TODO assert (attrNames for) all exist
    nft-update-addresses.config = pipe others [
      (concatMap (i: flip map ifCfg.effectiveGroups (g: i.nft-update-addresses.for.${g} or { })))
      (filter (x: x != { }))
      mkMerge
    ];
  };

}
