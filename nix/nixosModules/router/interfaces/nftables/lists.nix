{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  nftCfg = ifCfg.nftables;
  inherit (builtins) attrValues concatMap concatStringsSep;
  inherit (lib) ruleFromList types;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) pipe;
  setType =
    typ:
    types.submodule (
      { config, name, ... }:
      {
        options = {
          objType = mkOption {
            internal = typ != null;
            description = "type of nftables 'list'/set";
            type = types.enum [
              null
              "map"
              "set"
            ];
            default = typ;
          };
          content = mkOption {
            description = "content of nftables block";
            type = types.lines;
          };
          elements = mkOption {
            description = "elements to add to the nftables 'list'/set";
            type = with types; listOf str;
            default = [ ];
          };
          # outputs
          fullName = mkOption {
            description = "name of nftables 'list'/set (with interface-specific prefix attached)";
            type = types.str;
            default = "${nftCfg.namePrefix}-${name}";
          };
        };
        config.content = ruleFromList config.elements (set: ''
          elements = { ${set} }
        '');
      }
    );
in
{

  options.nftables = {
    # neither do reflect the definitions set on the other
    lists = mkOption {
      internal = true; # TODO not internal
      description = "abstraction of map/set";
      type = types.attrsOf (setType null);
      default = { };
    };
    maps = mkOption {
      internal = true; # TODO not internal
      type = types.attrsOf (setType "map");
      default = { };
    };
    sets = mkOption {
      internal = true; # TODO not internal
      type = types.attrsOf (setType "set");
      default = { };
    };
  };

  # TODO better error messages (via assert) for invalid map duplications
  config.nftables = {
    # build content
    content = pipe nftCfg [
      (x: [
        x.lists
        x.maps
        x.sets
      ])
      (concatMap attrValues)
      (map (cfg: ''
        ${cfg.objType} ${cfg.fullName} {
          ${cfg.content}
        }
      ''))
      (concatStringsSep "")
    ];
  };

}
