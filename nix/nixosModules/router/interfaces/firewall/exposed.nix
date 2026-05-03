{ globalArg, ... }@interface:
let
  inherit (globalArg) lib libBNet;
  ifCfg = interface.config;
  fwCfg = ifCfg.firewall;
  expCfg = fwCfg.exposed;
  # helpers
  inherit (builtins)
    attrNames
    concatMap
    concatStringsSep
    elemAt
    filter
    listToAttrs
    mapAttrs
    ;
  inherit (lib) nftConcat nftConcatComment;
  inherit (lib.attrsets)
    attrByPath
    collect
    genAttrs
    mapAttrsRecursive
    ;
  inherit (libBNet.lists) groupByMult;
  inherit (lib.modules) mkIf;
  inherit (lib.options) mkOption showOption;
  inherit (lib.trivial) flip pipe;
  reqAttrByPath = path: attrByPath path (abort "attribute set is missing ${showOption path}");
  ipCommands = {
    "ipv4" = "ip";
    "ipv6" = "ip6";
  };
  genIpVersions = genAttrs (attrNames ipCommands);
  genIpCommands = flip mapAttrs ipCommands;
  # type
  exposedIpType =
    with lib.optionSets;
    subCombined [
      defaultRules
      commentRule
      multiIpRule
      multiSourceRule
      deviceRule
      {
        options.downstream = mkOption {
          internal = true;
          # should be readOnly, but not possible due to _clone
          default = ifCfg.name;
        };
      }
    ];
  exposedFullType =
    with lib.optionSets;
    subCombined [
      exposedIpType
      protoWildcardRule
    ];
  exposedPortType =
    with lib.optionSets;
    subCombined [
      exposedIpType
      portRule
    ];
  # values
  # TODO exposed: add support for differences per interface
  extendRecursive = attrs: list: mapAttrsRecursive (_: v: v ++ list) attrs;
  setType = mapAttrsRecursive (_: nftConcat) {
    static = genIpVersions (ipV: [
      #"ifname"
      "${ipV}_addr"
      "${ipV}_addr"
      "inet_proto"
      "inet_service"
    ]);
    network = genIpVersions (ipV: [
      #"ifname"
      "${ipV}_addr"
      "inet_proto"
      "inet_service"
    ]);
  };
  setGen = mapAttrs (_: g: genIpVersions (_: r: nftConcatComment r (g r))) {
    static = r: [
      #r.sourceInterface
      r.sourceIP
      r.dynamicDestination
      r.protocol
      r.port
    ];
    network = r: [
      #r.sourceInterface
      r.dynamicDestination
      r.protocol
      r.port
    ];
  };
  setMatcher =
    (flip pipe [
      (mapAttrs (_: genIpCommands)) # adds new level
      (mapAttrsRecursive (_: nftConcat))
    ])
      {
        static = ipV: ipC: [
          #"iifname"
          "${ipC} saddr"
          "${ipC} daddr"
          "meta l4proto"
          "th dport"
        ];
        network = ipV: ipC: [
          #"iifname"
          "${ipC} daddr"
          "meta l4proto"
          "th dport"
        ];
      };
  setPrefix = mapAttrs (_: genIpCommands) {
    static = ipV: ipC: "";
    network = ipV: ipC: "iifname . ${ipC} saddr == @all_${ipV}net ";
  };
  rules = pipe expCfg [
    (x: x.fullDevices ++ x.devicePorts)
    (concatMap (x: x._multiRules))
    (groupByMult [
      (x: if x.source == "network" then "network" else "static")
      (x: x.ipVersion)
    ])
    (mapAttrsRecursive (
      path: ruleList: rec {
        inherit path;
        sourceKind = elemAt path 0;
        ipVersion = elemAt path 1;
        name = "${ipVersion}-exposed-${sourceKind}";
        fullName =
          if ipVersion == "ipv6" then "nftua-${ifCfg.name}-${name}" else ifCfg.nftables.sets.${name}.fullName;
        elements = map (reqAttrByPath path setGen) ruleList;
        rule = (reqAttrByPath path setPrefix) + (reqAttrByPath path setMatcher) + " == @${fullName} accept";
        type = reqAttrByPath path setType;
      }
    ))
    (collect (x: x ? path))
  ];
in
{

  options.firewall.exposed = {
    devicePorts = mkOption {
      description = "List of device’s ports exposed.";
      type = lib.types.listOf exposedPortType;
      default = [ ];
    };
    fullDevices = mkOption {
      # TODO test & document & comment on pingable: does this include pings? (question because of hard ICMPv6 filtering)
      description = ''
        List of fully exposed devices.
      '';
      type = lib.types.listOf exposedFullType;
      default = [ ];
    };
  };

  # assumption: all interfaces use same nftables table, hence I can insert "others content" here
  # TODO (runtime performance) we can group these exposures from all interfaces and collect them in one single set
  config = mkIf (rules != [ ]) {
    # rules
    # TODO (cosmetic) only push rules to interfaces used
    firewall.forwardFromRules.all = pipe rules [
      (map (x: x.rule))
      (concatStringsSep "\n")
    ];
    # IPv4 sets
    nftables.sets = pipe rules [
      (filter (x: x.ipVersion == "ipv4"))
      (map (x: {
        inherit (x) name;
        value = {
          content = ''
            type ${x.type}
            flags interval
          '';
          inherit (x) elements;
        };
      }))
      listToAttrs
    ];
    # IPv6 sets (in dynamic)
    nft-update-addresses.config.sets = pipe rules [
      (filter (x: x.ipVersion == "ipv6"))
      (map (x: {
        name = x.fullName;
        value = {
          set_type = "set";
          inherit (x) type elements;
          flags = "interval";
        };
      }))
      listToAttrs
    ];
  };

}
