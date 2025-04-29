{ globalArg, others, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  ifOpts = interface.options;
  dnatCfg = ifCfg.dstnat;
  dnatOpts = interface.options.dstnat;
  # helpers
  inherit (builtins)
    any
    concatMap
    elem
    filter
    toString
    ;
  inherit (lib) types;
  inherit (lib.lists) unique;
  inherit (lib.trivial) pipe;
in
{

  options.dstnat = {
    upstreams = lib.mkOption {
      description = ''
        Names of the interfaces to which .forUpstreams will be applied to.

        Can be overwritten by each entry in .forUpstreams.
      '';
      type = with types; listOf ifName;
      default = [ ];
    };
    forUpstreams = lib.mkOption {
      description = ''
        DNAT mappings applied to packets on the interfaces listed in .upstreams.
        Intended for DNAT mappings to devices on this interface.
      '';
      type = types.extendsSubmodule dnatOpts.local {
        options = {
          upstreams = lib.mkOption {
            description = ''
              Names of the interfaces to which this dnat rule will be applied to.
            '';
            type = with types; listOf ifName;
            default = dnatCfg.upstreams;
            defaultText = lib.literalExpression "ifCfg.dstnat.upstreams";
          };
          downstream = lib.mkOption {
            internal = true;
            # TODO should be readOnly, but not possible due to _clone
            default = ifCfg.name;
          };
        };
      };
      default = [ ];
    };
  };

  config = {
    assertions = [
      # TODO (minor) group support for upstream
      (
        let
          known = map (x: x.name) others;
          unknown = pipe dnatCfg.forUpstreams [
            (concatMap (x: x.upstreams))
            unique
            (filter (x: !elem x known))
          ];
        in
        {
          assertion = unknown == [ ];
          message = "Unknown upstream interfaces: ${toString unknown}";
        }
      )
    ];
    warnings = [
      # TODO output which are broken
      (lib.mkIf (any (
        x: x.upstreams == [ ]
      ) dnatCfg.forUpstreams) "Some upstream DNAT rules have no upstreams defined, making them useless")
    ];
    # copy upstream rules to correct upstream
    dstnat.local = pipe others [
      # TODO (efficency) instead of others, use new all option
      # (reflection is not bad here, but evaluating the same for all interfaces is good)
      (concatMap (x: x.dstnat.forUpstreams))
      (filter (x: elem ifCfg.name x.upstreams))
      (map (x: x._cloneFor ifOpts.dstnat.local))
    ];
  };

}
