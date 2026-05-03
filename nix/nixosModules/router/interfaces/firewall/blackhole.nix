{ globalArg, ... }@interface:
let
  inherit (globalArg) lib;
  ifCfg = interface.config;
  fwCfg = ifCfg.firewall;
  bhCfg = fwCfg.blackhole;
  pref = ifCfg.nftables.namePrefix;
  # helpers
  inherit (builtins)
    attrNames
    attrValues
    concatMap
    concatStringsSep
    foldl'
    groupBy
    mapAttrs
    removeAttrs
    ;
  inherit (lib)
    getIpVersion
    mapAttrsJoin
    mapListJoin
    mkDisableOption
    ruleFromList
    ;
  inherit (lib.attrsets) genAttrs;
  inherit (lib.lists) optionals singleton toposort;
  inherit (lib.network) netListMinus parseIP;
  inherit (lib.strings) conditionalString;
  inherit (lib.trivial) flip pipe;
  flat = concatMap (x: x);
  mkDefaultIf = cond: val: lib.mkDefault (lib.mkIf cond val);
  mkBlockOption =
    {
      description,
      kind,
      networks,
      ...
    }@args:
    lib.mkOption (
      {
        description = ''
          Whether to block ${kind} traffic.
          If enabled, such traffic not routed in or out of that interface.

          ${description}

          To be concete: this option affects following IP networks (excluding other sets more specific networks):
          ${concatStringsSep "\n" (map (ip: "- `${ip}`") networks)}

          Traffic to & from the router host is not affected.
        '';
        type = lib.types.bool;
      }
      // removeAttrs args [
        "description"
        "kind"
        "networks"
      ]
    );
  mkFullBlockOption =
    {
      description ? kind,
      descriptions ? { },
      kind,
      networks ? { },
      defaultSince ? null, # "" == ever (TODO NixOS test)
    }:
    let
      desc =
        genAttrs [
          "ipv4"
          "ipv6"
        ] (_: description)
        // descriptions;
    in
    lib.mkOption {
      description = "Options for blocking ${kind} traffic.";
      type = lib.types.submodule (blk: {
        options = {
          all = mkBlockOption {
            description =
              if desc.ipv4 != desc.ipv6 then
                ''
                  This means in case of:
                  - IPv4: traffic to/from ${desc.ipv4}
                  - IPv6: traffic to/from ${desc.ipv6}
                ''
              else
                "In IPv4 & IPv6, this means traffic to/from ${description}.";
            default = defaultSince != null && lib.versionAtLeast lib.version defaultSince;
            inherit kind;
          };
          ipv4 = mkBlockOption {
            description = "In case of IPv4, this means traffic from/to ${desc.ipv4}.";
            inherit kind;
            networks = networks.ipv4;
            default = blk.config.all;
            defaultText = lib.literalExpression "cfg.all";
          };
          ipv6 = mkBlockOption {
            description = "In case of IPv6, this means traffic from/to ${desc.ipv6}.";
            inherit kind;
            networks = networks.ipv6;
            default = blk.config.all;
            defaultText = lib.literalExpression "cfg.all";
          };
          toBlock = lib.mkOption {
            internal = true;
            readOnly = true;
            default = flat [
              (optionals (blk.config.ipv4 or false) networks.ipv4)
              (optionals (blk.config.ipv6 or false) networks.ipv6)
            ];
          };
          toAccept = lib.mkOption {
            internal = true;
            readOnly = true;
            default = flat [
              (optionals (!blk.config.ipv4 or true) networks.ipv4)
              (optionals (!blk.config.ipv6 or true) networks.ipv6)
            ];
          };
        };
      });
    };
  # Lists generated from following sources:
  # - https://www.iana.org/assignments/ipv4-address-space/ipv4-address-space.xhtml#note17
  # - https://www.iana.org/assignments/ipv6-address-space/ipv6-address-space.xhtml
  ipSets = {
    # technically non routable
    unspecified = {
      kind = "unspecified-address";
      networks.ipv6 = singleton "::/128"; # RFC 4291
      defaultSince = "";
    };
    ipv4Mapped = {
      kind = "IPv4-mapped-addresses";
      descriptions.ipv6 = "IPv4-mapped Addresses per RFC 4291";
      networks.ipv6 = singleton "::ffff:0.0/96";
      defaultSince = "";
    };
    discardOnly = {
      kind = "special-address";
      descriptions.ipv6 = "Discard-Only Address Block per RFC 6666";
      networks.ipv6 = singleton "100::/64";
      defaultSince = "";
    };
    documentation = {
      kind = "documentation-address";
      networks.ipv4 = [
        "192.0.2.0/24" # RFC 5737 - TEST-NET-1
        "198.51.100.0/24" # RFC 5737 - TEST-NET-2
        "203.0.113.0/24" # RFC 5737 - TEST-NET-3
      ];
      networks.ipv6 = [
        "2001:db8::/32" # RFC 3849 - Documentation
        "3fff::/20" # RFC 9637 - Documentation
      ];
      # documentation stuff should not be used globally
      defaultSince = "";
    };
    # interface-local
    loopback = {
      kind = "loopback";
      networks.ipv4 = [
        "0.0.0.0/32" # RFC 791 - This host in this network
        "127.0.0.0/8"
      ];
      networks.ipv6 = singleton "::1/128"; # RFC 4291
      defaultSince = "";
    };
    multicastLoopback = {
      kind = "local broadcast & multicast";
      descriptions.ipv6 = "interface-local multicast addresses (ffx1::)";
      networks.ipv6 = [
        # ffx1::/16 - TODO desc
        "ff01::/16"
        "ff11::/16"
        "ff21::/16"
        "ff31::/16"
        "ff41::/16"
        "ff51::/16"
        "ff61::/16"
        "ff71::/16"
        "ff81::/16"
        "ff91::/16"
        "ffa1::/16"
        "ffb1::/16"
        "ffc1::/16"
        "ffd1::/16"
        "ffe1::/16"
        "fff1::/16"
      ];
      # routing local multicast is technically forbidden
      defaultSince = "";
    };
    # link-local
    linklocal = {
      kind = "link local";
      networks.ipv4 = [
        "0.0.0.0/8" # RFC 791 - This network
        "169.254.0.0/16" # RFC 3927 - Link Local
      ];
      networks.ipv6 = singleton "fe80::/10"; # RFC 4291
      defaultSince = "";
    };
    multicastLocal = {
      kind = "local broadcast & multicast";
      descriptions = {
        ipv4 = "limited broadcast and multicast addresses";
        ipv6 = "link-local multicast addresses (ffx2::)";
      };
      networks.ipv4 = [
        "224.0.0.0/24"
        "255.255.255.255/32" # Limited Broadcast - RFC 919
      ];
      networks.ipv6 = [
        # ffx2::/16 - TODO desc
        "ff02::/16"
        "ff12::/16"
        "ff22::/16"
        "ff32::/16"
        "ff42::/16"
        "ff52::/16"
        "ff62::/16"
        "ff72::/16"
        "ff82::/16"
        "ff92::/16"
        "ffa2::/16"
        "ffb2::/16"
        "ffc2::/16"
        "ffd2::/16"
        "ffe2::/16"
        "fff2::/16"
      ];
      defaultSince = "";
    };
    # site-local
    private = {
      kind = "private";
      descriptions.ipv4 = "private network addresses per RFC 1918";
      networks.ipv4 = [
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
      ];
    };
    uniqueLocal = {
      kind = "unique-local";
      descriptions.ipv6 = "unique local addresses";
      networks.ipv6 = singleton "fc00::/7";
    };
    cgnat = {
      kind = "carrier-grade NAT addresses";
      networks.ipv4 = singleton "100.64.0.0/10";
    };
    # public
    multicastRoutable = {
      kind = "routable multicast";
      descriptions = {
        ipv4 = "routable multicast addresses (most of 224.0.0.0/4)";
        ipv6 = "routable multicast addresses (most of ff00::/8)";
      };
      networks.ipv4 = singleton "224.0.0.0/8";
      networks.ipv6 = singleton "ff00::/8";
    };
    # anycast protocols
    as112 = {
      kind = "AS112";
      description = "the AS112 networks per RFC 7534 & 7535";
      networks.ipv4 = [
        "192.31.196.0/24" # RFC 7535 - AS112-v4
        "192.175.48.0/24" # RFC 7534 - Direct Delegation AS112 Service
      ];
      networks.ipv6 = [
        "2001:4:112::/48" # RFC 7535 - AS112-v6
        "2620:4f:8000::/48" # RFC 7534 - Direct Delegation AS112
      ];
    };
    amt = {
      kind = "Automatic Multicast Tunneling";
      description = "AMT network per RFC 7450";
      networks.ipv4 = singleton "192.52.193.0/24";
      networks.ipv6 = singleton "2001:3::/32";
    };
    benchmarking = {
      kind = "benchmarking";
      networks.ipv4 = [
        "192.175.48.0/24" # RFC 2544 - Benchmarking
      ];
      networks.ipv6 = [
        "2001:2::/48" # RFC 5180 - Benchmarking
      ];
      # normally, we do not participate in such benchmarks
      # TODO move to kind
      defaultSince = "";
    };
    pcp = {
      kind = "Port Control Protocol (PCP)";
      description = "the PCP address per RFC 7723";
      networks.ipv4 = singleton "192.0.0.9/32";
      networks.ipv6 = singleton "2001:1::1/128";
    };
    turnDiscovery = {
      kind = "Traversal Using Relays around NAT autodiscovery";
      description = "the TURN anycast address per RFC 8155";
      networks.ipv4 = singleton "192.0.0.10/32";
      networks.ipv6 = singleton "2001:1::2/128";
    };
    # transition protocols
    # TODO split addresses for transition mechanisms
    transition = {
      kind = "transition";
      descriptions.ipv4 = "e.g. 6to4, DS-Lite";
      descriptions.ipv6 = "e.g. IPv4-IPv6 Translation, Teredo";
      networks.ipv4 = [
        "192.0.0.0/29" # RFC 7335 - IPv4 Service Continuity Prefix (formerly DS-Lite)
        "192.0.0.170/32" # RFC 7050 - NAT64/DNS64 Discovery
        "192.88.99.0/24" # RFC 3068 - 6to4 Relay Anycast
      ];
      networks.ipv6 = [
        "64:ff9b::/96" # RFC 6052 - IPv4-IPv6 Translation
        "64:ff9b:1::/96" # RFC 8215 - IPv4-IPv6 Translation
        "2001::/32" # RFC 8190 - TEREDO
        "2002::/16" # RFC 3056 - 6to4
      ];
      # we are normally dual-stack
      # TODO move to kind
      defaultSince = "";
    };
    transitionLocal = {
      kind = ''"non-routable transition"-address'';
      networks.ipv4 = [
        "192.0.0.8/32" # RFC 7600 - IPv4 dummy address
      ];
    };
    # addresses unused as of today (might be used in the future)
    reserved = {
      kind = "reserved-address";
      networks.ipv4 = [
        "192.0.0.0/24" # RFC 6890 - IETF Protocol Assignments
        "240.0.0.0/4" # RFC 1112 - formerly Class E
      ];
      networks.ipv6 = [
        "0000::/8"
        "0100::/8"
        "0200::/7"
        "0400::/6"
        "0800::/5"
        "1000::/4"
        "2001::/23" # RFC 2928 - IETF Protocol Assignments
        "4000::/3"
        "6000::/3"
        "8000::/3"
        "a000::/3"
        "c000::/3"
        "e000::/4"
        "f000::/5"
        "f800::/6"
        "fe00::/9"
        "fec0::/10"
      ];
      defaultSince = "";
    };
  };
  ipSetsList = attrValues ipSets;
  mapSetIP = fun: set: set // { networks = mapAttrs fun set.networks; };
  allNets =
    ipV:
    pipe ipSetsList [
      (concatMap (x: x.networks.${ipV} or [ ]))
      (map parseIP)
      # toposort would find a cycle on non-unique lists
      (x: (toposort (net: net.contains) x).result)
    ];
  ipSetsFixed = flip mapAttrs ipSets (
    mapSetIP (ipV: ipL: toString (foldl' netListMinus ipL (allNets ipV)))
  );
in
{

  options.firewall.blackhole = {
    enable = mkDisableOption "the blackhole mechanism on this interface";
    list = lib.mkOption {
      description = ''
        List of IP addresses & networks which should not be routed to & from at all.

        Users should prefer to use
        the predefined sets in `ifCfg.firewall.blackhole.sets` concerning specific traffic
        and should only use this option directly for further needs.

        Traffic to & from the router host is not affected.
      '';
      type = with lib.types; listOf ipNetwork;
      default = [ ];
    };
    exceptions = lib.mkOption {
      description = ''
        List IP networks which should be routed
        despite being listed (indirectly) in `ifCfg.firewall.blackhole.list`.

        Users should prefer to use
        the predefined sets in `ifCfg.firewall.blackhole.sets` concerning specific traffic
        and should only use this option directly for further needs.

        Traffic to & from the router host is not affected.
      '';
      type = with lib.types; listOf ipNetwork;
      default = [ ];
      example = [ "127.0.0.0/16" ];
    };
    sets = mapAttrs mkFullBlockOption ipSetsFixed;
  };

  config.firewall = lib.mkIf bhCfg.enable {
    blackhole = {
      # cross dependencies
      sets = {
        transitionLocal = mkDefaultIf bhCfg.transition true;
      };
      # apply predefined sets
      list = concatMap (x: x.selected) bhCfg.selected;
    };
    # effective rules
    forwardRules = lib.mkOrder 600 "jump ${pref}-blackhole";
    nftables.content =
      let
        rules = mapAttrs (_: groupBy getIpVersion) { inherit (bhCfg) list exceptions; };
        ipVersions = attrNames rules.list;
        ipCmd = ipV: if ipV == "ipv4" then "ip" else "ip6";
        except =
          ipV:
          conditionalString rules.${ipV}.exceptions
            "${ipCmd ipV} daddr != ${pref}-${ipV}-blackhole-exceptions";
        block = ipV: "${except ipV} ${ipCmd ipV} daddr == ${pref}-${ipV}-blackhole-list";
      in
      # only apply rules if anything is really blocked
      lib.mkIf (bhCfg.list != [ ]) ''
        ${mapAttrsJoin "" rules (kind: ''
          ${flip mapAttrsJoin "" (
            ipV:
            flip ruleFromList (set: ''
              set ${pref}-${ipV}-blackhole-${kind} {
                type ${ipV}_addr;
                flags interval;
                auto-merge;
                elements = { ${set} }
              }
            '')
          )}
        '')}
        chain ${pref}blackhole {
          ${mapListJoin "\n" ipVersions block}
        }
      '';
  };

}
