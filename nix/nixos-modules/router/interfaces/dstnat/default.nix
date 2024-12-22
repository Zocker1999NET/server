{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  dnatCfg = ifCfg.dstnat;
  nftCfg = ifCfg.nftables;
  # helpers
  inherit (builtins)
    attrNames
    concatMap
    concatStringsSep
    elemAt
    filter
    groupBy
    isList
    isString
    listToAttrs
    mapAttrs
    replaceStrings
    typeOf
    ;
  inherit (lib)
    escapeNftablesStr
    nftConcat
    nftConcatComment
    nftMarks
    optionSets
    ;
  inherit (lib.asserts) assertMsg;
  inherit (lib.attrsets)
    attrByPath
    collect
    genAttrs
    mapAttrsRecursive
    ;
  inherit (lib.lists) groupByMult sublist;
  inherit (lib.modules) mkOrder;
  inherit (lib.options) showOption;
  inherit (lib.trivial) flip pipe;
  reqAttrByPath = path: attrByPath path (abort "attribute set is missing ${showOption path}");
  ipReplacements = {
    from = [
      "ipvX"
      "ipX nexthdr"
      "ipX "
    ];
    to.ipv4 = [
      "ipv4"
      "ip protocol"
      "ip "
    ];
    to.ipv6 = [
      "ipv6"
      "ip6 nexthdr"
      "ip6 "
    ];
  };
  genIpVersions = genAttrs (attrNames ipReplacements.to);
  replaceStringsDepth =
    from: to: input:
    if isList input then map (replaceStrings from to) input else replaceStrings from to input;
  genIpVar = ipV: replaceStringsDepth ipReplacements.from ipReplacements.to.${ipV};
  genIpVariants =
    input:
    assert assertMsg (isList input || isString input) "expected list or string, got ${typeOf input}";
    flip mapAttrs ipReplacements.to (_: to: replaceStringsDepth ipReplacements.from to input);
  # type
  dnatMapType =
    with optionSets;
    subCombined [
      defaultRules
      commentRule
      multiIpRule
      multiSourceRule
      deviceRule
      dnatRule
    ];
  # TODO move id into optionSets
  # unique port identifier (for duplication matching & fancy debug print outs)
  dnatId = entry: "${entry.ipVersion}:${entry.protocol}:${toString entry.wanPort}";
  # values
  # TODO exposed: add support for differences per interface
  setElemType =
    (flip pipe [
      (mapAttrsRecursive (_: genIpVariants)) # adds new level
      (mapAttrsRecursive (_: nftConcat))
    ])
      {
        dnat.static = [
          #"ifname"
          "ipvX_addr"
          "inet_proto"
          "inet_service"
          ":"
          "ipvX_addr"
          "inet_service"
        ];
        dnat.network = [
          #"ifname"
          "inet_proto"
          "inet_service"
          ":"
          "ipvX_addr"
          "inet_service"
        ];
        allow.static = [
          #"ifname"
          "ipvX_addr"
          "ipvX_addr"
          "inet_proto"
          "inet_service"
        ];
        allow.network = [
          #"ifname"
          "ipvX_addr"
          "inet_proto"
          "inet_service"
        ];
      };
  setMatcher =
    (flip pipe [
      (mapAttrsRecursive (_: genIpVariants)) # adds new level
      (mapAttrsRecursive (_: nftConcat))
    ])
      {
        dnat.static = [
          #"iifname"
          "ipX saddr"
          "ipX nexthdr" # "meta l4proto"
          "th dport"
          # maps to …
        ];
        dnat.network = [
          #"iifname"
          "ipX nexthdr" # "meta l4proto"
          "th dport"
          # maps to …
        ];
        allow.static = [
          #"iifname"
          "ipX saddr"
          "ipX daddr"
          "meta l4proto"
          "th dport"
        ];
        allow.network = [
          #"iifname"
          "ipX daddr"
          "meta l4proto"
          "th dport"
        ];
      };
  setGen = mapAttrsRecursive (_: g: genIpVersions (_: r: nftConcatComment r (g r))) {
    dnat.static = r: [
      #r.sourceInterface
      r.sourceIP
      r.protocol
      r.wanPort
      ":"
      r.dynamicDestination
      r.lanPort
    ];
    dnat.network = r: [
      #r.sourceInterface
      r.protocol
      r.wanPort
      ":"
      r.dynamicDestination
      r.lanPort
    ];
    allow.static = r: [
      #r.sourceInterface
      r.sourceIP
      r.dynamicDestination
      r.protocol
      r.lanPort
    ];
    allow.network = r: [
      #r.sourceInterface
      r.dynamicDestination
      r.protocol
      r.lanPort
    ];
  };
  setPrefix =
    pipe
      {
        static = "";
        network = "iifname . ipX saddr == @all_ipvXnet ";
      }
      [
        (mapAttrs (_: genIpVariants))
        (x: genAttrs (attrNames setMatcher) (_: x))
      ];
  rules = pipe dnatCfg.local [
    (concatMap (x: x._multiRules))
    (groupByMult [
      (x: if x.source == "network" then "network" else "static")
      (x: x.ipVersion)
      (x: x.downstream)
    ])
    (x: {
      dnat = x;
      allow = x;
    })
    (mapAttrsRecursive (
      _path: ruleList: rec {
        path = sublist 0 3 _path; # relevant for other vars
        variant = elemAt _path 0;
        sourceKind = elemAt _path 1;
        ipVersion = elemAt _path 2;
        downstream = elemAt _path 3;
        setType = if variant == "dnat" then "map" else "set";
        name = "${ipVersion}-dstnat-${variant}-${sourceKind}";
        fullName =
          if ipVersion == "ipv6" then "nftua-${ifCfg.name}-${name}" else nftCfg.lists.${name}.fullName;
        elements = map (reqAttrByPath path setGen) ruleList;
        rule =
          let
            prefix = reqAttrByPath path setPrefix;
            matcher = reqAttrByPath path setMatcher;
          in
          if variant == "dnat" then
            "${prefix}${genIpVar ipVersion "dnat ipX to"} ${matcher} map @${fullName}"
          else
            "${prefix}${matcher} == @${fullName} accept";
        type = reqAttrByPath path setElemType;
      }
    ))
    (collect (x: x ? path))
  ];

in
{

  imports = [
    # files
    ./upstream.nix
  ];

  options.dstnat = {
    local = lib.mkOption {
      description = ''
        DNAT mappings applied to packets incoming on this (WAN) interface.
      '';
      internal = true; # makes no sense to use
      type = lib.types.listOf dnatMapType;
      default = [ ];
    };
  };

  config = lib.mkIf (dnatCfg.local != [ ]) ({

    assertions = [
      # TODO check for ip type of sources
      # TODO rewrite deduplication check
      # TODO allow same wanPort on non-overlapping sources
      # - what about to make with special "network" -> maybe handle as all
      /*
        (
          let
            duplicated = pipe dnatCfg.local [
              (groupBy dnatId)
              (filterAttrs (_: l: length l > 1))
              attrNames
            ];
          in
          {
            assertion = duplicated == [ ];
            message = "following ports are DNAT-mapped multiple times: ${toString duplicated}";
          }
        )
      */
    ];

    # before normal filter rules to avoid exposed rules
    firewall.forwardRules = mkOrder 990 ''
      ct status & dnat == dnat accept comment "handled by chain ${
        nftCfg.chains."dstnat-forward".fullName
      }"
    '';

    # TODO (minor) test NAT reflection over third interface (e.g. vpn -> wan -> lan)

    # rules
    nftables.chains = {
      dstnat = ''
        type nat hook prerouting priority dstnat; policy accept;
        ip daddr != @${ifCfg.name}v4addr accept comment "only look for our stuff"
        ip6 daddr != @${ifCfg.name}v6addr accept comment "only look for our stuff"
        # establish reachability from interfaces expected SNAT (TODO does not work as expected)
        #ip version 4 iifname . ${escapeNftablesStr ifCfg.name} @srcnat-ipv4 ${nftMarks.snatShortcutted.metaSet}
        #ip6 version 6 iifname . ${escapeNftablesStr ifCfg.name} @srcnat-ipv6 ${nftMarks.snatShortcutted.metaSet}
        ${pipe rules [
          (filter (x: x.variant == "dnat"))
          (map (x: x.rule))
          (concatStringsSep "\n")
        ]}
      '';
      # this allows us to effect all interfaces
      # (allowing self-reachability & reachability from other interfaces)
      dstnat-forward = ''
        # preamble
        type filter hook forward priority filter; policy drop;
        ct status & dnat != dnat accept comment "only dnat traffic"
        ct original ip daddr != @${ifCfg.name}v4addr accept comment "only our stuff"
        ct original ip6 daddr != @${ifCfg.name}v6addr accept comment "only our stuff"
        # rules
        jump global comment "allow established connections";
        iifname . oifname == @same-if ${nftMarks.snatShortcutted.metaSet} comment "NAT reflection"
        ${pipe rules [
          (filter (x: x.variant == "allow"))
          (map (x: x.rule))
          (concatStringsSep "\n")
        ]}
        drop comment "we know all permitted dstnat targets"
      '';
    };

    # IPv4 sets
    nftables.lists = pipe rules [
      (filter (x: x.ipVersion == "ipv4"))
      (map (x: {
        inherit (x) name;
        value = {
          objType = x.setType;
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
    nft-update-addresses.for = pipe rules [
      (filter (x: x.ipVersion == "ipv6"))
      (groupBy (x: x.downstream))
      (mapAttrs (
        _:
        flip pipe [
          (map (x: {
            name = x.fullName;
            value = {
              set_type = x.setType;
              inherit (x) type elements;
              flags = "interval";
            };
          }))
          listToAttrs
          (x: { sets = x; })
        ]
      ))
    ];

  });

}
