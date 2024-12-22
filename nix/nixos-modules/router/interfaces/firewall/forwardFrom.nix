{ globalArg, others, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  fwCfg = ifCfg.firewall;
  inherit (globalArg.cfg.references) interfaceGroups;
  inherit (builtins)
    attrNames
    concatMap
    elem
    filter
    groupBy
    isAttrs
    mapAttrs
    ;
  inherit (lib) types;
  inherit (lib.attrsets) filterAttrs mapAttrsToList;
  inherit (lib.modules) dischargeProperties mkMerge mkOrder;
  inherit (lib.options) mkOption;
  inherit (lib.trivial) flip pipe;
in
{

  options.firewall = {
    forwardFromRules = mkOption {
      description = ''
        Forward rules for packets from the defined one to this interface.

        I.e. the example declares rules applied to packets
        from a interface "wan0" to this interface.

        This option supports interface groups.

        This is the complementary setting of {option}`ifCfg.firewall.forwardToRules`,
        rules defined here will be copied to the other interface respective ruleset
        while preserving their mkOrder priority.
        Read the description of the complementary setting to learn
        which order priorities are recommended to use.
      '';
      type = types.attrsOf types.lines;
      default = { };
      example = {
        lan0 = "accept";
      };
    };
  };

  config = {
    assertions = [
      (
        let
          known = attrNames interfaceGroups;
          unknown = pipe fwCfg.forwardFromRules [
            filterAttrs
            (_: rules: rules != "")
            attrNames
            (filter (x: !elem x known))
          ];
        in
        {
          assertion = unknown == [ ];
          message = "Unknown interfaces/groups with forwardFromRules: ${toString unknown}";
        }
      )
    ];

    # for the other side
    # TODO (debug improvement) migrate file source (seems impossible on this level)
    firewall.forwardToRules = pipe others [
      # extract "to" interface
      (map (i: {
        to = i.name;
        value = i.ifOptions.firewall.forwardFromRules.definitionsWithLocations;
      }))
      # separate definitions, preserving location
      (concatMap (ref: flip map ref.value (def: ref // { inherit (def) file value; })))
      # assertion to prevent unexpected bug that definitions are not already discharged
      (map (
        { value, ... }@def:
        assert value._type or null == null;
        def
      ))
      # separate "from" interface/group
      (concatMap (def: flip mapAttrsToList def.value (from: value: def // { inherit from value; })))
      # discharge subvalues
      (concatMap (
        valGroup:
        pipe valGroup.value [
          dischargeProperties
          (map (value: valGroup // { inherit value; }))
        ]
      ))
      # annotate rules
      (map (
        x:
        let
          isMkOrder = isAttrs x.value && x.value._type or "" == "order";
          rules = if isMkOrder then x.value.content else x.value;
          keepOrder = if isMkOrder then mkOrder x.value.priority else (x: x);
        in
        x
        // {
          value = keepOrder ''
            # START: from .interfaces.${x.to}.firewall.forwardFromRules.${x.from}, defined in ${x.file}
            ${rules}
            # END: rule list
          '';
        }
      ))
      # TODO performance: extract upper part, as the same for all interfaces
      # filter
      (filter (x: elem x.from ifCfg.effectiveGroups))
      # finalize
      (groupBy (i: i.to))
      (mapAttrs (
        _:
        flip pipe [
          (map (x: x.value))
          mkMerge
        ]
      ))
    ];
  };

}
