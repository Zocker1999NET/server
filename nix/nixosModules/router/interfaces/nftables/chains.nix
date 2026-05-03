{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  nftCfg = ifCfg.nftables;
  inherit (builtins) isString mapAttrs;
  inherit (lib) mapAttrsJoin types;
  inherit (lib.lists) singleton;
  inherit (lib.options) mkOption;
  chainType = types.submodule (
    { config, name, ... }:
    {
      options = {
        # explicitly non mergeable to avoid unintended clashes
        content = mkOption { type = types.str; };
        # outputs
        fullName = mkOption {
          readOnly = true;
          default = "${nftCfg.namePrefix}-${name}";
        };
      };
    }
  );
in
{

  options.nftables = {
    chains = mkOption {
      internal = true; # TODO not internal
      type = with types; attrsOf (either str chainType);
      apply = mapAttrs (
        name: x:
        if isString x then
          chainType.merge (singleton name) (singleton {
            file = ./chains.nix;
            value.content = x;
          })
        else
          x
      );
    };
  };

  config.nftables.content = mapAttrsJoin "" nftCfg.chains (
    name: cfg: ''
      chain ${cfg.fullName} {
        ${cfg.content}
      }
    ''
  );

}
